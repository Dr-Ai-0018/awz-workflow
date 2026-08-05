"""Git subprocess boundary for Reference Library operations."""

from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path
from typing import List, Optional

from .errors import ReferenceLibraryError


def run_git(
    arguments: List[str], cwd: Optional[Path] = None, check: bool = True
) -> subprocess.CompletedProcess[str]:
    environment = os.environ.copy()
    environment["GIT_TERMINAL_PROMPT"] = "0"
    command = ["git"]
    if cwd:
        command.extend(["-c", f"safe.directory={cwd.resolve(strict=False).as_posix()}"])
    command.extend(arguments)
    process = subprocess.run(
        command,
        cwd=str(cwd) if cwd else None,
        env=environment,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if check and process.returncode != 0:
        detail = process.stderr.strip() or process.stdout.strip() or f"exit {process.returncode}"
        raise ReferenceLibraryError(f"git {' '.join(arguments[:3])} failed: {detail}")
    return process


def require_git() -> None:
    if shutil.which("git") is None:
        raise ReferenceLibraryError("Git is required for Reference Library commands.")
