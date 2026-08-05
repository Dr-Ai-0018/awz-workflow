"""Resolved paths and path-safety checks."""

from __future__ import annotations

import os
from pathlib import Path

from .errors import ReferenceLibraryError


def resolved_path(value: str) -> Path:
    return Path(os.path.expandvars(value)).expanduser().resolve(strict=False)


def default_config_dir() -> Path:
    override = os.environ.get("AWZ_CONFIG_DIR")
    if override:
        return resolved_path(override)
    if os.name == "nt":
        local_app_data = os.environ.get("LOCALAPPDATA")
        if local_app_data:
            return resolved_path(str(Path(local_app_data) / "AWZ Workflow"))
        return resolved_path(str(Path.home() / "AppData" / "Local" / "AWZ Workflow"))
    xdg_config = os.environ.get("XDG_CONFIG_HOME")
    if xdg_config:
        return resolved_path(str(Path(xdg_config) / "awz-workflow"))
    return resolved_path(str(Path.home() / ".config" / "awz-workflow"))


def default_reference_root() -> Path:
    override = os.environ.get("AWZ_REFERENCE_ROOT")
    if override:
        return resolved_path(override)
    if os.name == "nt":
        d_drive = Path("D:/")
        if d_drive.exists():
            return resolved_path("D:/AWZ References")
        return resolved_path(str(Path.home() / "AWZ References"))
    xdg_data = os.environ.get("XDG_DATA_HOME")
    if xdg_data:
        return resolved_path(str(Path(xdg_data) / "awz-workflow" / "references"))
    return resolved_path(str(Path.home() / ".local" / "share" / "awz-workflow" / "references"))


def config_path() -> Path:
    return default_config_dir() / "config.json"


def is_within(path: Path, parent: Path) -> bool:
    try:
        common = os.path.commonpath([str(path.resolve(strict=False)), str(parent.resolve(strict=False))])
        return os.path.normcase(common) == os.path.normcase(str(parent.resolve(strict=False)))
    except ValueError:
        return False


def require_within(path: Path, parent: Path, label: str) -> Path:
    candidate = path.resolve(strict=False)
    root = parent.resolve(strict=False)
    if not is_within(candidate, root):
        raise ReferenceLibraryError(f"{label} escapes reference root: {candidate}")
    return candidate
