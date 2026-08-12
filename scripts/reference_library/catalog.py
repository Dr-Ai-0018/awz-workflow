"""Catalog validation, repository metadata and offline state inspection."""

from __future__ import annotations

import os
import re
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple
from urllib.parse import urlsplit, urlunsplit

from .config import SCHEMA_VERSION
from .errors import ReferenceLibraryError
from .git_tools import run_git
from .paths import require_within
from .storage import read_json


ID_PATTERN = re.compile(r"^[a-z0-9][a-z0-9._-]*$")
CATEGORY_PATTERN = re.compile(r"^[a-z0-9][a-z0-9._/-]*$")
DEFAULT_READ_FIRST = ("README.md", "README", "docs/README.md")
LICENSE_FILES = ("LICENSE", "LICENSE.md", "LICENSE.txt", "COPYING", "COPYING.md")


def validate_reference_id(value: str) -> str:
    normalized = value.strip().lower()
    if not ID_PATTERN.fullmatch(normalized):
        raise ReferenceLibraryError(
            "Reference id must start with a lowercase letter or digit and contain only lowercase letters, digits, '.', '_' or '-'."
        )
    return normalized


def validate_category(value: str) -> str:
    normalized = value.strip().lower().replace("\\", "/").strip("/")
    if not normalized or not CATEGORY_PATTERN.fullmatch(normalized):
        raise ReferenceLibraryError("Category must contain only safe lowercase path segments.")
    if any(part in ("", ".", "..") for part in normalized.split("/")):
        raise ReferenceLibraryError("Category cannot contain empty, '.' or '..' path segments.")
    return normalized


def sanitize_url(value: str) -> str:
    parsed = urlsplit(value)
    if not parsed.scheme:
        return value
    hostname = parsed.hostname or ""
    netloc = hostname
    if parsed.port:
        netloc = f"{netloc}:{parsed.port}"
    return urlunsplit((parsed.scheme, netloc, parsed.path, "", ""))


def validate_safe_url(value: str, label: str, *, require_path: bool = False) -> str:
    parsed = urlsplit(value)
    if parsed.scheme.lower() != "https" or not parsed.hostname:
        raise ReferenceLibraryError(f"{label} must be a valid https:// URL.")
    if require_path and not parsed.path.strip("/"):
        raise ReferenceLibraryError(f"{label} must include a repository path.")
    if parsed.username or parsed.password or parsed.query or parsed.fragment:
        raise ReferenceLibraryError(f"{label} cannot contain credentials, query parameters, or fragments.")
    return sanitize_url(value)


def validate_public_url(value: str) -> str:
    return validate_safe_url(value, "Public repository URL", require_path=True)


def validate_license_url(value: str) -> str:
    return validate_safe_url(value, "License URL")


def catalog_path(root: Path, reference_id: str) -> Path:
    return require_within(root / "catalog" / f"{reference_id}.json", root, "Catalog path")


def repo_path_from_catalog(root: Path, catalog: Dict[str, Any]) -> Path:
    relative = catalog.get("relativePath")
    if not isinstance(relative, str) or not relative:
        raise ReferenceLibraryError(f"Catalog {catalog.get('id', '<unknown>')} has no relativePath.")
    relative_path = Path(relative)
    if relative_path.is_absolute() or any(part == ".." for part in relative_path.parts):
        raise ReferenceLibraryError(f"Unsafe relativePath in catalog {catalog.get('id', '<unknown>')}: {relative}")
    return require_within(root / relative_path, root, "Repository path")


def normalize_catalog(data: Dict[str, Any], path: Path) -> Dict[str, Any]:
    schema_version = data.get("schemaVersion")
    if schema_version not in (1, SCHEMA_VERSION):
        raise ReferenceLibraryError(f"Unsupported catalog schemaVersion: {path}")
    normalized = {**data}
    normalized["schemaVersion"] = SCHEMA_VERSION
    repository_url = normalized.get("repositoryUrl")
    if isinstance(repository_url, str) and repository_url:
        parsed_repository = urlsplit(repository_url)
        if parsed_repository.scheme == "https":
            normalized["repositoryUrl"] = validate_public_url(repository_url)
        elif parsed_repository.scheme == "file" and not (
            parsed_repository.username
            or parsed_repository.password
            or parsed_repository.query
            or parsed_repository.fragment
        ):
            normalized["repositoryUrl"] = sanitize_url(repository_url)
        else:
            raise ReferenceLibraryError(f"Unsafe repository URL in catalog: {path}")
    license_url = normalized.get("licenseUrl")
    if isinstance(license_url, str) and license_url:
        normalized["licenseUrl"] = validate_license_url(license_url)
    normalized.setdefault("notes", "")
    normalized.setdefault("source", {"kind": "public-git"})
    normalized.setdefault("createdAt", None)
    normalized.setdefault("updatedAt", None)
    return normalized


def load_catalogs(root: Path) -> Dict[str, Dict[str, Any]]:
    catalog_dir = root / "catalog"
    if not catalog_dir.exists():
        return {}
    catalogs: Dict[str, Dict[str, Any]] = {}
    for path in sorted(catalog_dir.glob("*.json")):
        data = normalize_catalog(read_json(path, "reference catalog"), path)
        reference_id = validate_reference_id(str(data.get("id", "")))
        if reference_id in catalogs:
            raise ReferenceLibraryError(f"Duplicate reference id: {reference_id}")
        catalogs[reference_id] = data
    return catalogs


def split_values(values: Optional[Iterable[str]]) -> List[str]:
    result: List[str] = []
    for value in values or []:
        for item in value.split(","):
            cleaned = item.strip()
            if cleaned and cleaned not in result:
                result.append(cleaned)
    return result


def detect_version(repo_path: Path) -> Optional[str]:
    package_json = repo_path / "package.json"
    if package_json.exists():
        try:
            package = read_json(package_json, "package.json")
            version = package.get("version")
            if isinstance(version, str) and version.strip():
                return version.strip()
        except ReferenceLibraryError:
            pass
    version_file = repo_path / "VERSION"
    if version_file.exists():
        value = version_file.read_text(encoding="utf-8-sig", errors="replace").strip()
        if value:
            return value.splitlines()[0]
    return None


def detect_license(repo_path: Path) -> str:
    for filename in LICENSE_FILES:
        if (repo_path / filename).is_file():
            return filename
    return "unknown"


def default_read_first(repo_path: Path) -> List[str]:
    return [name for name in DEFAULT_READ_FIRST if (repo_path / name).is_file()][:1]


def repository_state(root: Path, catalog: Dict[str, Any]) -> Dict[str, Any]:
    reference_id = str(catalog.get("id", "<unknown>"))
    issues: List[str] = []
    try:
        repo_path = repo_path_from_catalog(root, catalog)
    except ReferenceLibraryError as exc:
        return {"id": reference_id, "path": "<invalid>", "status": "invalid", "issues": [str(exc)]}

    state: Dict[str, Any] = {
        "id": reference_id,
        "path": str(repo_path),
        "status": "ok",
        "issues": issues,
        "exists": repo_path.is_dir(),
        "dirty": False,
        "drifted": False,
    }
    if not repo_path.is_dir():
        issues.append("repository directory is missing")
        state["status"] = "missing"
        return state
    if not (repo_path / ".git").exists():
        issues.append("repository has no .git directory")
        state["status"] = "invalid"
        return state

    try:
        top_level = run_git(["rev-parse", "--show-toplevel"], cwd=repo_path).stdout.strip()
        if Path(top_level).resolve(strict=False) != repo_path.resolve(strict=False):
            issues.append("repository Git top-level does not match its catalog path")
            state["status"] = "invalid"
            return state
        head = run_git(["rev-parse", "HEAD"], cwd=repo_path).stdout.strip()
        branch_process = run_git(["symbolic-ref", "--short", "-q", "HEAD"], cwd=repo_path, check=False)
        branch = branch_process.stdout.strip() or "detached"
        remote_process = run_git(["remote", "get-url", "origin"], cwd=repo_path, check=False)
        remote = sanitize_url(remote_process.stdout.strip()) if remote_process.returncode == 0 else ""
        dirty = bool(run_git(["status", "--porcelain"], cwd=repo_path).stdout.strip())
    except ReferenceLibraryError as exc:
        issues.append(str(exc))
        state["status"] = "invalid"
        return state
    expected_revision = str(catalog.get("revision", ""))
    expected_remote = sanitize_url(str(catalog.get("repositoryUrl", "")))

    state.update({"head": head, "branch": branch, "remote": remote, "dirty": dirty})
    if expected_revision and head != expected_revision:
        state["drifted"] = True
        issues.append(f"HEAD differs from catalog revision {expected_revision}")
    if expected_remote and remote and expected_remote != remote:
        issues.append("origin remote differs from catalog repositoryUrl")
    if dirty:
        issues.append("repository worktree is dirty")

    for relative in catalog.get("readFirst", []):
        if not isinstance(relative, str):
            issues.append("readFirst contains a non-string value")
            continue
        try:
            candidate = require_within(repo_path / relative, repo_path, "readFirst path")
            if not candidate.exists():
                issues.append(f"readFirst file is missing: {relative}")
        except ReferenceLibraryError as exc:
            issues.append(str(exc))

    if issues:
        state["status"] = "warning" if all("dirty" in issue or "differs" in issue for issue in issues) else "error"
    return state


def status_rows(root: Path, catalogs: Dict[str, Dict[str, Any]]) -> Tuple[List[Dict[str, Any]], bool]:
    rows: List[Dict[str, Any]] = []
    has_errors = False
    for catalog in catalogs.values():
        state = repository_state(root, catalog)
        rows.append(state)
        if state["status"] != "ok":
            has_errors = True
    return rows, has_errors
