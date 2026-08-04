#!/usr/bin/env python3
"""AWZ Reference Library core CLI.

The core uses only Python's standard library. Project initialization does not
depend on this script; it powers the optional cross-project reference library.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple
from urllib.parse import urlsplit, urlunsplit


SCHEMA_VERSION = 1
ID_PATTERN = re.compile(r"^[a-z0-9][a-z0-9._-]*$")
CATEGORY_PATTERN = re.compile(r"^[a-z0-9][a-z0-9._/-]*$")
DEFAULT_READ_FIRST = ("README.md", "README", "docs/README.md")
LICENSE_FILES = (
    "LICENSE",
    "LICENSE.md",
    "LICENSE.txt",
    "COPYING",
    "COPYING.md",
)


class ReferenceLibraryError(RuntimeError):
    pass


def write_stderr(message: str) -> None:
    print(f"Error: {message}", file=sys.stderr)


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


def read_json(path: Path, label: str) -> Dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8-sig") as handle:
            data = json.load(handle)
    except FileNotFoundError as exc:
        raise ReferenceLibraryError(f"{label} not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ReferenceLibraryError(f"Invalid JSON in {label} {path}: {exc}") from exc
    if not isinstance(data, dict):
        raise ReferenceLibraryError(f"{label} must contain a JSON object: {path}")
    return data


def write_json_atomic(path: Path, data: Dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary_name: Optional[str] = None
    try:
        with tempfile.NamedTemporaryFile(
            "w",
            encoding="utf-8",
            newline="\n",
            dir=str(path.parent),
            prefix=f".{path.name}.",
            suffix=".tmp",
            delete=False,
        ) as handle:
            temporary_name = handle.name
            json.dump(data, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary_name, path)
    finally:
        if temporary_name and os.path.exists(temporary_name):
            os.unlink(temporary_name)


def write_text_atomic(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary_name: Optional[str] = None
    try:
        with tempfile.NamedTemporaryFile(
            "w",
            encoding="utf-8",
            newline="\n",
            dir=str(path.parent),
            prefix=f".{path.name}.",
            suffix=".tmp",
            delete=False,
        ) as handle:
            temporary_name = handle.name
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary_name, path)
    finally:
        if temporary_name and os.path.exists(temporary_name):
            os.unlink(temporary_name)


def load_config() -> Tuple[Dict[str, Any], Path, bool]:
    path = config_path()
    if not path.exists():
        data = {
            "schemaVersion": SCHEMA_VERSION,
            "referenceRoot": str(default_reference_root()),
            "defaultCloneDepth": 1,
            "networkPolicy": "explicit",
            "executionPolicy": "source-only",
        }
        return data, path, False
    data = read_json(path, "AWZ config")
    if data.get("schemaVersion") != SCHEMA_VERSION:
        raise ReferenceLibraryError(f"Unsupported AWZ config schemaVersion in {path}")
    root = data.get("referenceRoot")
    if not isinstance(root, str) or not root.strip():
        raise ReferenceLibraryError(f"referenceRoot is missing from AWZ config: {path}")
    data["referenceRoot"] = str(resolved_path(root))
    return data, path, True


def library_root(config: Dict[str, Any]) -> Path:
    root = resolved_path(str(config["referenceRoot"]))
    anchor = Path(root.anchor).resolve(strict=False)
    if root == anchor or root == Path.home().resolve(strict=False):
        raise ReferenceLibraryError(f"Reference root is too broad: {root}")
    return root


def ensure_library_layout(root: Path) -> None:
    for relative in ("catalog", "repos", "context-cache", "logs"):
        (root / relative).mkdir(parents=True, exist_ok=True)


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
    return urlunsplit((parsed.scheme, netloc, parsed.path, parsed.query, parsed.fragment))


def validate_public_url(value: str) -> str:
    parsed = urlsplit(value)
    if parsed.scheme.lower() != "https" or not parsed.hostname or not parsed.path.strip("/"):
        raise ReferenceLibraryError("First-version public references require a valid https:// Git URL.")
    if parsed.username or parsed.password:
        raise ReferenceLibraryError("Credential-bearing repository URLs are not allowed.")
    return sanitize_url(value)


def run_git(arguments: List[str], cwd: Optional[Path] = None, check: bool = True) -> subprocess.CompletedProcess[str]:
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


def load_catalogs(root: Path) -> Dict[str, Dict[str, Any]]:
    catalog_dir = root / "catalog"
    if not catalog_dir.exists():
        return {}
    catalogs: Dict[str, Dict[str, Any]] = {}
    for path in sorted(catalog_dir.glob("*.json")):
        data = read_json(path, "reference catalog")
        if data.get("schemaVersion") != SCHEMA_VERSION:
            raise ReferenceLibraryError(f"Unsupported catalog schemaVersion: {path}")
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

    head = run_git(["rev-parse", "HEAD"], cwd=repo_path).stdout.strip()
    branch_process = run_git(["symbolic-ref", "--short", "-q", "HEAD"], cwd=repo_path, check=False)
    branch = branch_process.stdout.strip() or "detached"
    remote_process = run_git(["remote", "get-url", "origin"], cwd=repo_path, check=False)
    remote = sanitize_url(remote_process.stdout.strip()) if remote_process.returncode == 0 else ""
    dirty = bool(run_git(["status", "--porcelain"], cwd=repo_path).stdout.strip())
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


def project_mapping_path(project: Path) -> Path:
    return project / ".awz" / "references.json"


def load_project_mapping(project: Path, allow_missing: bool = False) -> Dict[str, Any]:
    path = project_mapping_path(project)
    if not path.exists() and allow_missing:
        return {"schemaVersion": SCHEMA_VERSION, "references": []}
    data = read_json(path, "project reference mapping")
    if data.get("schemaVersion") != SCHEMA_VERSION or not isinstance(data.get("references"), list):
        raise ReferenceLibraryError(f"Invalid project reference mapping schema: {path}")
    return data


def require_project(value: str) -> Path:
    project = resolved_path(value)
    if not project.is_dir():
        raise ReferenceLibraryError(f"Project directory does not exist: {project}")
    return project


def command_configure(args: argparse.Namespace) -> int:
    root = library_root({"referenceRoot": args.root})
    path = config_path()
    existing: Dict[str, Any] = {}
    if path.exists():
        existing = read_json(path, "AWZ config")
        if existing.get("schemaVersion") not in (None, SCHEMA_VERSION):
            raise ReferenceLibraryError(f"Unsupported AWZ config schemaVersion in {path}")
    data = {
        **existing,
        "schemaVersion": SCHEMA_VERSION,
        "referenceRoot": str(root),
        "defaultCloneDepth": args.depth,
        "networkPolicy": "explicit",
        "executionPolicy": "source-only",
    }
    if args.dry_run:
        print(f"DryRun: would write AWZ config: {path}")
        print(f"DryRun: would create reference layout: {root}")
        print("DryRun: would not clone or update repositories.")
        return 0
    ensure_library_layout(root)
    write_json_atomic(path, data)
    print(f"Configured Reference Library: {root}")
    print(f"Config: {path}")
    return 0


def command_add(args: argparse.Namespace) -> int:
    require_git()
    reference_id = validate_reference_id(args.id)
    category = validate_category(args.category)
    config, _, configured = load_config()
    root = library_root(config)
    destination = require_within(root / "repos" / Path(category) / reference_id, root, "Repository destination")
    metadata_path = catalog_path(root, reference_id)
    if destination.exists():
        raise ReferenceLibraryError(f"Reference destination already exists: {destination}")
    if metadata_path.exists():
        raise ReferenceLibraryError(f"Reference catalog already exists: {metadata_path}")

    source = args.url
    clone_source = source
    local_safe_directory: Optional[str] = None
    local_bundle = False
    if args.allow_local:
        local_source = resolved_path(source)
        if not local_source.exists():
            raise ReferenceLibraryError(f"Local source does not exist: {local_source}")
        local_bundle = local_source.is_file()
        clone_source = str(local_source) if local_bundle else local_source.as_uri()
        stored_url = validate_public_url(args.canonical_url) if args.canonical_url else clone_source
        if local_source.is_dir():
            local_safe_directory = (local_source / ".git").as_posix()
    else:
        stored_url = validate_public_url(source)

    print(f"Reference root: {root} ({'configured' if configured else 'default'})")
    if args.dry_run:
        print(f"DryRun: would clone {sanitize_url(stored_url)}")
        print(f"DryRun: destination {destination}")
        print(f"DryRun: would write catalog {metadata_path}")
        print("DryRun: would not initialize submodules or execute repository code.")
        return 0

    ensure_library_layout(root)
    destination.parent.mkdir(parents=True, exist_ok=True)
    clone_arguments: List[str] = []
    if local_safe_directory:
        clone_arguments.extend(["-c", f"safe.directory={local_safe_directory}"])
    clone_arguments.append("clone")
    if not local_bundle:
        clone_arguments.extend(["--depth", str(args.depth)])
    clone_arguments.extend(["--no-recurse-submodules", clone_source, str(destination)])
    run_git(clone_arguments)
    try:
        if args.canonical_url:
            run_git(["remote", "set-url", "origin", stored_url], cwd=destination)
        head = run_git(["rev-parse", "HEAD"], cwd=destination).stdout.strip()
        branch_process = run_git(["symbolic-ref", "--short", "-q", "HEAD"], cwd=destination, check=False)
        read_first = split_values(args.read_first) or default_read_first(destination)
        metadata: Dict[str, Any] = {
            "schemaVersion": SCHEMA_VERSION,
            "id": reference_id,
            "name": args.name or reference_id,
            "repositoryUrl": sanitize_url(stored_url),
            "relativePath": destination.relative_to(root).as_posix(),
            "revision": head,
            "version": detect_version(destination),
            "branch": branch_process.stdout.strip() or "detached",
            "tags": split_values(args.tag),
            "trust": "source-only",
            "readFirst": read_first,
            "useWhen": split_values(args.use_when),
            "avoidWhen": split_values(args.avoid_when),
            "license": detect_license(destination),
            "licenseUrl": args.license_url or None,
        }
        write_json_atomic(metadata_path, metadata)
    except Exception as exc:
        raise ReferenceLibraryError(
            f"Repository clone was preserved at {destination}, but catalog creation failed: {exc}"
        ) from exc

    print(f"Added reference {reference_id}: {destination}")
    print(f"Revision: {head}")
    print(f"Catalog: {metadata_path}")
    return 0


def command_list(_: argparse.Namespace) -> int:
    config, path, configured = load_config()
    root = library_root(config)
    catalogs = load_catalogs(root)
    print(f"Reference root: {root} ({'configured' if configured else 'default'})")
    print(f"Config: {path}{'' if configured else ' (not written)'}")
    if not catalogs:
        print("No references registered.")
        return 0
    for reference_id, catalog in catalogs.items():
        state = repository_state(root, catalog)
        version = catalog.get("version") or "unknown"
        print(f"{reference_id}\t{state['status']}\t{version}\t{state['path']}")
    return 0


def command_show(args: argparse.Namespace) -> int:
    reference_id = validate_reference_id(args.id)
    config, _, _ = load_config()
    root = library_root(config)
    path = catalog_path(root, reference_id)
    data = read_json(path, "reference catalog")
    data["state"] = repository_state(root, data)
    print(json.dumps(data, ensure_ascii=False, indent=2))
    return 0


def command_map(args: argparse.Namespace) -> int:
    reference_id = validate_reference_id(args.id)
    project = require_project(args.project)
    config, _, _ = load_config()
    catalogs = load_catalogs(library_root(config))
    if reference_id not in catalogs:
        raise ReferenceLibraryError(f"Reference id is not registered: {reference_id}")
    mapping = load_project_mapping(project, allow_missing=True)
    references = mapping["references"]
    entry = next((item for item in references if isinstance(item, dict) and item.get("id") == reference_id), None)
    new_entry = {"id": reference_id, "purpose": args.purpose or "", "required": bool(args.required)}
    if entry is None:
        references.append(new_entry)
    else:
        entry.clear()
        entry.update(new_entry)
    references.sort(key=lambda item: str(item.get("id", "")))
    path = project_mapping_path(project)
    if args.dry_run:
        print(f"DryRun: would map {reference_id} in {path}")
        return 0
    write_json_atomic(path, mapping)
    print(f"Mapped {reference_id}: {path}")
    return 0


def command_unmap(args: argparse.Namespace) -> int:
    reference_id = validate_reference_id(args.id)
    project = require_project(args.project)
    mapping = load_project_mapping(project)
    original = len(mapping["references"])
    mapping["references"] = [
        item for item in mapping["references"] if not (isinstance(item, dict) and item.get("id") == reference_id)
    ]
    if len(mapping["references"]) == original:
        raise ReferenceLibraryError(f"Reference id is not mapped in project: {reference_id}")
    path = project_mapping_path(project)
    if args.dry_run:
        print(f"DryRun: would unmap {reference_id} from {path}")
        return 0
    write_json_atomic(path, mapping)
    print(f"Unmapped {reference_id}; global clone was preserved.")
    return 0


def context_markdown(project: Path, root: Path, mapping: Dict[str, Any], catalogs: Dict[str, Dict[str, Any]]) -> Tuple[str, bool]:
    lines = [
        "# Reference Context",
        "",
        "> 由 AWZ Reference Library 生成。先读当前项目，只按任务相关性读取下面的外部参考；默认禁止自动执行参考仓库代码。",
        "",
        f"- Project: `{project}`",
        f"- Reference root: `{root}`",
        "",
    ]
    required_missing = False
    references = mapping.get("references", [])
    if not references:
        lines.extend(["当前项目没有映射参考项目。", ""])
    for entry in references:
        if not isinstance(entry, dict):
            continue
        reference_id = str(entry.get("id", ""))
        required = bool(entry.get("required"))
        purpose = str(entry.get("purpose", ""))
        catalog = catalogs.get(reference_id)
        heading = reference_id
        if catalog is not None and catalog.get("name") and catalog.get("name") != reference_id:
            heading = f"{catalog['name']} ({reference_id})"
        lines.extend([f"## {heading}", "", f"- Purpose: {purpose or '未填写'}", f"- Required: {str(required).lower()}"])
        if catalog is None:
            lines.extend(["- Status: unresolved", "- Catalog: missing", ""])
            required_missing = required_missing or required
            continue
        state = repository_state(root, catalog)
        lines.extend(
            [
                f"- Status: {state['status']}",
                f"- Path: `{state['path']}`",
                f"- Revision: `{catalog.get('revision') or 'unknown'}`",
                f"- Trust: `{catalog.get('trust') or 'source-only'}`",
                f"- License: `{catalog.get('license') or 'unknown'}`",
                f"- Tags: {', '.join(catalog.get('tags', [])) or '无'}",
            ]
        )
        if catalog.get("useWhen"):
            lines.extend(["- Use when:", *[f"  - {item}" for item in catalog["useWhen"]]])
        if catalog.get("avoidWhen"):
            lines.extend(["- Avoid when:", *[f"  - {item}" for item in catalog["avoidWhen"]]])
        lines.append("- Read first:")
        repo_path = Path(str(state["path"]))
        for relative in catalog.get("readFirst", []):
            lines.append(f"  - `{repo_path / relative}`")
        if state.get("issues"):
            lines.extend(["- Issues:", *[f"  - {item}" for item in state["issues"]]])
        lines.append("")
    return "\n".join(lines).rstrip() + "\n", required_missing


def command_context(args: argparse.Namespace) -> int:
    project = require_project(args.project)
    mapping = load_project_mapping(project)
    config, _, _ = load_config()
    root = library_root(config)
    catalogs = load_catalogs(root)
    content, required_missing = context_markdown(project, root, mapping, catalogs)
    if args.output:
        requested_output = Path(os.path.expandvars(args.output)).expanduser()
        output = resolved_path(str(requested_output if requested_output.is_absolute() else project / requested_output))
    else:
        output = project / "docs" / "agent-room" / "reference-context.md"
    if not is_within(output, project):
        raise ReferenceLibraryError(f"Context output must stay inside the project: {output}")
    if args.dry_run:
        print(f"DryRun: would write reference context: {output}")
        print(content)
        return 1 if required_missing else 0
    write_text_atomic(output, content)
    print(f"Wrote reference context: {output}")
    return 1 if required_missing else 0


def status_rows(root: Path, catalogs: Dict[str, Dict[str, Any]]) -> Tuple[List[Dict[str, Any]], bool]:
    rows: List[Dict[str, Any]] = []
    has_errors = False
    for catalog in catalogs.values():
        state = repository_state(root, catalog)
        rows.append(state)
        if state["status"] != "ok":
            has_errors = True
    return rows, has_errors


def command_status(args: argparse.Namespace, strict: bool) -> int:
    config, path, configured = load_config()
    root = library_root(config)
    catalogs = load_catalogs(root)
    rows, has_errors = status_rows(root, catalogs)
    print(f"Config: {path}{'' if configured else ' (default, not written)'}")
    print(f"Reference root: {root}")
    print(f"Root exists: {str(root.is_dir()).lower()}")
    if strict and not root.is_dir():
        has_errors = True
    if not rows:
        print("References: 0")
    for state in rows:
        print(f"Reference {state['id']}: {state['status']} ({state['path']})")
        for issue in state.get("issues", []):
            print(f"  - {issue}")

    if args.project:
        project = require_project(args.project)
        mapping = load_project_mapping(project)
        mapped_ids = []
        for entry in mapping["references"]:
            if not isinstance(entry, dict):
                has_errors = True
                continue
            reference_id = str(entry.get("id", ""))
            mapped_ids.append(reference_id)
            if reference_id not in catalogs:
                print(f"Project reference {reference_id}: unresolved")
                if entry.get("required") or strict:
                    has_errors = True
        print(f"Project mappings: {len(mapped_ids)}")
    return 1 if strict and has_errors else 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="AWZ Reference Library")
    subparsers = parser.add_subparsers(dest="command", required=True)

    configure = subparsers.add_parser("configure", help="Configure the machine-level reference root.")
    configure.add_argument("--root", required=True)
    configure.add_argument("--depth", type=int, default=1)
    configure.add_argument("--dry-run", action="store_true")
    configure.set_defaults(handler=command_configure)

    add = subparsers.add_parser("add", help="Clone and register a public reference repository.")
    add.add_argument("--id", required=True)
    add.add_argument("--name")
    add.add_argument("--url", required=True)
    add.add_argument("--category", default="general")
    add.add_argument("--depth", type=int, default=1)
    add.add_argument("--tag", action="append")
    add.add_argument("--read-first", action="append")
    add.add_argument("--use-when", action="append")
    add.add_argument("--avoid-when", action="append")
    add.add_argument("--license-url")
    add.add_argument("--canonical-url", help=argparse.SUPPRESS)
    add.add_argument("--allow-local", action="store_true", help=argparse.SUPPRESS)
    add.add_argument("--dry-run", action="store_true")
    add.set_defaults(handler=command_add)

    list_parser = subparsers.add_parser("list", help="List registered references.")
    list_parser.set_defaults(handler=command_list)

    show = subparsers.add_parser("show", help="Show one reference catalog and local state.")
    show.add_argument("--id", required=True)
    show.set_defaults(handler=command_show)

    for name, handler in (("map", command_map), ("unmap", command_unmap)):
        command = subparsers.add_parser(name, help=f"{name.title()} a project reference.")
        command.add_argument("--project", required=True)
        command.add_argument("--id", required=True)
        if name == "map":
            command.add_argument("--purpose", default="")
            command.add_argument("--required", action="store_true")
        command.add_argument("--dry-run", action="store_true")
        command.set_defaults(handler=handler)

    context = subparsers.add_parser("context", help="Generate project-local AI reference context.")
    context.add_argument("--project", required=True)
    context.add_argument("--output")
    context.add_argument("--dry-run", action="store_true")
    context.set_defaults(handler=command_context)

    status = subparsers.add_parser("status", help="Show offline reference state.")
    status.add_argument("--project")
    status.set_defaults(handler=lambda args: command_status(args, strict=False))

    doctor = subparsers.add_parser("doctor", help="Run strict offline validation.")
    doctor.add_argument("--project")
    doctor.set_defaults(handler=lambda args: command_status(args, strict=True))
    return parser


def main(argv: Optional[List[str]] = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if hasattr(args, "depth") and args.depth < 1:
        raise ReferenceLibraryError("Clone depth must be at least 1.")
    return int(args.handler(args) or 0)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ReferenceLibraryError as error:
        write_stderr(str(error))
        raise SystemExit(1)
