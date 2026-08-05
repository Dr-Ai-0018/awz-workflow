"""Machine-readable plans, results and stale-plan detection primitives."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional

from .errors import ReferenceLibraryError


PLAN_SCHEMA_VERSION = 1
RESULT_SCHEMA_VERSION = 1


def canonical_json(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def file_snapshot(path: Path) -> Dict[str, Any]:
    """Return a cheap, stable state fingerprint without reading directories."""
    resolved = path.resolve(strict=False)
    snapshot: Dict[str, Any] = {"path": str(resolved), "exists": resolved.exists()}
    if not snapshot["exists"]:
        snapshot["kind"] = "missing"
        return snapshot
    if resolved.is_dir():
        snapshot["kind"] = "directory"
        return snapshot
    snapshot["kind"] = "file"
    digest = hashlib.sha256()
    with resolved.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    snapshot["sha256"] = digest.hexdigest()
    return snapshot


def snapshot_paths(paths: Iterable[Path]) -> List[Dict[str, Any]]:
    unique = {str(path.resolve(strict=False)): path for path in paths}
    return [file_snapshot(unique[key]) for key in sorted(unique)]


def build_plan(
    operation: str,
    changes: List[Dict[str, Any]],
    snapshots: List[Dict[str, Any]],
    warnings: Optional[List[str]] = None,
    blocked_by: Optional[List[str]] = None,
    recovery: Optional[List[str]] = None,
) -> Dict[str, Any]:
    plan = {
        "schemaVersion": PLAN_SCHEMA_VERSION,
        "operation": operation,
        "changes": changes,
        "warnings": warnings or [],
        "blockedBy": blocked_by or [],
        "recovery": recovery or [],
        "snapshots": snapshots,
    }
    plan["planHash"] = hashlib.sha256(canonical_json(plan).encode("utf-8")).hexdigest()
    return plan


def require_matching_plan(plan: Dict[str, Any], supplied_hash: Optional[str]) -> None:
    if not supplied_hash:
        return
    actual_hash = str(plan.get("planHash", ""))
    if supplied_hash != actual_hash:
        raise ReferenceLibraryError(
            "Plan is stale or does not match this request. Re-run the DryRun preview before applying changes."
        )


def operation_result(
    operation: str,
    exit_code: int,
    *,
    dry_run: bool,
    plan: Optional[Dict[str, Any]] = None,
    data: Optional[Dict[str, Any]] = None,
    warnings: Optional[List[str]] = None,
    blocked_by: Optional[List[str]] = None,
    recovery: Optional[List[str]] = None,
) -> Dict[str, Any]:
    return {
        "schemaVersion": RESULT_SCHEMA_VERSION,
        "operation": operation,
        "dryRun": dry_run,
        "plan": plan,
        "changes": [] if plan is None else plan["changes"],
        "warnings": warnings if warnings is not None else ([] if plan is None else plan["warnings"]),
        "blockedBy": blocked_by if blocked_by is not None else ([] if plan is None else plan["blockedBy"]),
        "recovery": recovery if recovery is not None else ([] if plan is None else plan["recovery"]),
        "data": data or {},
        "exitCode": exit_code,
    }


def print_result(result: Dict[str, Any]) -> None:
    print(json.dumps(result, ensure_ascii=False, indent=2))
