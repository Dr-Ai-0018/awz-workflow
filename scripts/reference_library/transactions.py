"""Durable, redacted transaction records for Reference Library writes."""

from __future__ import annotations

import copy
import re
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, List, Mapping, Optional, Set

from .storage import write_json_atomic


TRANSACTION_SCHEMA_VERSION = 1
TRANSACTION_STATES = {"planned", "applying", "completed", "failed", "rolled_back"}
ALLOWED_STATE_TRANSITIONS = {
    "planned": {"applying", "failed"},
    "applying": {"completed", "failed"},
    "failed": {"rolled_back"},
    "completed": set(),
    "rolled_back": set(),
}
SENSITIVE_KEY_PARTS = (
    "authorization",
    "credential",
    "password",
    "secret",
    "token",
    "cookie",
    "api_key",
    "apikey",
)
URL_PATTERN = re.compile(r"https?://[^\s\"'<>]+", re.IGNORECASE)


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def redact_url(value: str) -> str:
    """Remove URL credentials, query parameters and fragments without logging them."""
    from urllib.parse import urlsplit, urlunsplit

    parsed = urlsplit(value)
    if parsed.scheme.lower() not in ("http", "https") or not parsed.hostname:
        return value
    hostname = parsed.hostname
    netloc = f"{hostname}:{parsed.port}" if parsed.port else hostname
    return urlunsplit((parsed.scheme, netloc, parsed.path, "", ""))


def redact_string(value: str) -> str:
    return URL_PATTERN.sub(lambda match: redact_url(match.group(0)), value)


def redact_sensitive(value: Any, key: str = "") -> Any:
    """Return a JSON-safe deep copy with secrets and URL credentials removed."""
    normalized_key = key.lower().replace("-", "_")
    if any(part in normalized_key for part in SENSITIVE_KEY_PARTS):
        return "[redacted]"
    if isinstance(value, Mapping):
        return {str(item_key): redact_sensitive(item_value, str(item_key)) for item_key, item_value in value.items()}
    if isinstance(value, (list, tuple)):
        return [redact_sensitive(item) for item in value]
    if isinstance(value, Path):
        return str(value)
    if isinstance(value, str):
        return redact_string(value)
    if value is None or isinstance(value, (bool, int, float)):
        return value
    return redact_string(str(value))


class ReferenceTransaction:
    """Track one write plan from preview-compatible plan to terminal state."""

    def __init__(self, root: Path, operation: str, plan: Dict[str, Any]) -> None:
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
        transaction_id = f"{timestamp}-{uuid.uuid4().hex[:8]}"
        self.path = root / "logs" / "transactions" / f"{transaction_id}.json"
        actions = redact_sensitive(copy.deepcopy(plan.get("changes", [])))
        created_at = utc_now()
        self._completed_indexes: Set[int] = set()
        self.record: Dict[str, Any] = {
            "schemaVersion": TRANSACTION_SCHEMA_VERSION,
            "transactionId": transaction_id,
            "operation": operation,
            "createdAt": created_at,
            "updatedAt": created_at,
            "state": "planned",
            "planHash": str(plan.get("planHash", "")),
            "actions": actions,
            "completed": [],
            "remaining": copy.deepcopy(actions),
            "recovery": [],
            "error": None,
        }
        self._write()

    @property
    def transaction_id(self) -> str:
        return str(self.record["transactionId"])

    def summary(self) -> Dict[str, Any]:
        return {
            "transactionId": self.transaction_id,
            "state": self.record["state"],
            "path": str(self.path),
            "completed": len(self.record["completed"]),
            "remaining": len(self.record["remaining"]),
            "recovery": list(self.record["recovery"]),
        }

    def begin_apply(self) -> None:
        self._set_state("applying")

    def complete_action(self, index: int) -> None:
        if self.record["state"] != "applying":
            raise ValueError("Transaction actions can only complete while applying.")
        actions: List[Dict[str, Any]] = self.record["actions"]
        if index < 0 or index >= len(actions):
            raise IndexError(f"Transaction action index is out of range: {index}")
        self._completed_indexes.add(index)
        self.record["completed"] = [copy.deepcopy(action) for i, action in enumerate(actions) if i in self._completed_indexes]
        self.record["remaining"] = [copy.deepcopy(action) for i, action in enumerate(actions) if i not in self._completed_indexes]
        self._touch_and_write()

    def complete(self) -> None:
        if self.record["state"] != "applying":
            raise ValueError("A transaction can only complete from the applying state.")
        self._completed_indexes = set(range(len(self.record["actions"])))
        self.record["completed"] = copy.deepcopy(self.record["actions"])
        self.record["remaining"] = []
        self.record["recovery"] = []
        self.record["error"] = None
        self._set_state("completed")

    def fail(self, error: BaseException, recovery: Optional[Iterable[str]] = None) -> None:
        self.record["error"] = redact_string(str(error))
        self.record["recovery"] = [redact_string(str(item)) for item in (recovery or [])]
        self._set_state("failed")

    def _set_state(self, state: str) -> None:
        if state not in TRANSACTION_STATES:
            raise ValueError(f"Unsupported transaction state: {state}")
        current_state = str(self.record["state"])
        if state not in ALLOWED_STATE_TRANSITIONS[current_state]:
            raise ValueError(f"Invalid transaction state transition: {current_state} -> {state}")
        self.record["state"] = state
        self._touch_and_write()

    def _touch_and_write(self) -> None:
        self.record["updatedAt"] = utc_now()
        self._write()

    def _write(self) -> None:
        write_json_atomic(self.path, self.record)
