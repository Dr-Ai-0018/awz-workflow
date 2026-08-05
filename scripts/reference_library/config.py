"""Machine-level Reference Library configuration and layout."""

from __future__ import annotations

from pathlib import Path
from typing import Any, Dict, Tuple

from .errors import ReferenceLibraryError
from .paths import config_path, default_reference_root, resolved_path
from .storage import read_json


SCHEMA_VERSION = 2


def default_config() -> Dict[str, Any]:
    return {
        "schemaVersion": SCHEMA_VERSION,
        "referenceRoot": str(default_reference_root()),
        "defaultCloneDepth": 1,
        "networkPolicy": "explicit",
        "executionPolicy": "source-only",
        "knownProjects": [],
        "trashRetentionDays": 30,
        "logRetentionDays": 90,
    }


def normalize_config(data: Dict[str, Any], path: Path) -> Dict[str, Any]:
    schema_version = data.get("schemaVersion")
    if schema_version not in (1, SCHEMA_VERSION):
        raise ReferenceLibraryError(f"Unsupported AWZ config schemaVersion in {path}")
    root = data.get("referenceRoot")
    if not isinstance(root, str) or not root.strip():
        raise ReferenceLibraryError(f"referenceRoot is missing from AWZ config: {path}")
    normalized = {**data}
    normalized["schemaVersion"] = SCHEMA_VERSION
    normalized["referenceRoot"] = str(resolved_path(root))
    normalized.setdefault("defaultCloneDepth", 1)
    normalized.setdefault("networkPolicy", "explicit")
    normalized.setdefault("executionPolicy", "source-only")
    normalized.setdefault("knownProjects", [])
    normalized.setdefault("trashRetentionDays", 30)
    normalized.setdefault("logRetentionDays", 90)
    return normalized


def load_config() -> Tuple[Dict[str, Any], Path, bool]:
    path = config_path()
    if not path.exists():
        return default_config(), path, False
    return normalize_config(read_json(path, "AWZ config"), path), path, True


def library_root(config: Dict[str, Any]) -> Path:
    root = resolved_path(str(config["referenceRoot"]))
    anchor = Path(root.anchor).resolve(strict=False)
    if root == anchor or root == Path.home().resolve(strict=False):
        raise ReferenceLibraryError(f"Reference root is too broad: {root}")
    return root


def ensure_library_layout(root: Path) -> None:
    for relative in ("catalog", "repos", "context-cache", "logs/transactions", "trash"):
        (root / relative).mkdir(parents=True, exist_ok=True)
