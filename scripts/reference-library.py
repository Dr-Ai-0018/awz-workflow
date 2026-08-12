#!/usr/bin/env python3
"""Thin CLI entry point for the AWZ Reference Library.

The domain implementation is split under ``reference_library`` so the future
TUI can consume the same config, catalog, project and Git boundaries without
parsing this program's human-readable output.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

from reference_library.catalog import (
    catalog_path,
    default_read_first,
    detect_license,
    detect_version,
    load_catalogs,
    repository_state,
    sanitize_url,
    split_values,
    status_rows,
    validate_category,
    validate_license_url,
    validate_public_url,
    validate_reference_id,
)
from reference_library.config import SCHEMA_VERSION, default_config, ensure_library_layout, library_root, load_config
from reference_library.contracts import build_plan, operation_result, print_result, require_matching_plan, snapshot_paths
from reference_library.errors import ReferenceLibraryError
from reference_library.git_tools import require_git, run_git
from reference_library.paths import config_path, require_within, resolved_path
from reference_library.projects import (
    context_markdown,
    load_project_mapping,
    project_mapping_path,
    require_project,
    resolve_context_output,
)
from reference_library.storage import write_json_atomic, write_text_atomic


def write_stderr(message: str) -> None:
    print(f"Error: {message}", file=sys.stderr)


def emit_json_result(
    args: argparse.Namespace,
    operation: str,
    exit_code: int,
    *,
    dry_run: bool,
    plan: Optional[Dict[str, Any]] = None,
    data: Optional[Dict[str, Any]] = None,
) -> bool:
    if not getattr(args, "json_output", False):
        return False
    print_result(operation_result(operation, exit_code, dry_run=dry_run, plan=plan, data=data))
    return True


def write_plan(
    operation: str,
    changes: List[Dict[str, Any]],
    snapshot_targets: List[Path],
    validated_inputs: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    return build_plan(
        operation,
        changes,
        snapshot_paths(snapshot_targets),
        validated_inputs=validated_inputs,
    )


def validate_apply_plan(args: argparse.Namespace, plan: Dict[str, Any]) -> None:
    if args.json_output and not args.plan_hash:
        raise ReferenceLibraryError("Machine-readable apply requires --plan-hash from the prior DryRun preview.")
    require_matching_plan(plan, args.plan_hash)


def command_configure(args: argparse.Namespace) -> int:
    root = library_root({"referenceRoot": args.root})
    path = config_path()
    existing: Dict[str, Any] = {}
    if path.exists():
        from reference_library.storage import read_json

        existing = read_json(path, "AWZ config")
        if existing.get("schemaVersion") not in (None, 1, SCHEMA_VERSION):
            raise ReferenceLibraryError(f"Unsupported AWZ config schemaVersion in {path}")
    data = {
        **default_config(),
        **existing,
        "schemaVersion": SCHEMA_VERSION,
        "referenceRoot": str(root),
        "defaultCloneDepth": args.depth,
        "networkPolicy": "explicit",
        "executionPolicy": "source-only",
    }
    plan = write_plan(
        "reference.configure",
        [
            {"kind": "write-json", "target": str(path), "summary": "写入机器级 Reference Library 配置"},
            {"kind": "ensure-layout", "target": str(root), "summary": "创建或验证 Reference Library 目录结构"},
        ],
        [path, root],
        {"root": str(root), "depth": args.depth},
    )
    if args.dry_run:
        if emit_json_result(args, "reference.configure", 0, dry_run=True, plan=plan, data={"config": data}):
            return 0
        print(f"DryRun: would write AWZ config: {path}")
        print(f"DryRun: would create reference layout: {root}")
        print("DryRun: would not clone or update repositories.")
        return 0
    validate_apply_plan(args, plan)
    ensure_library_layout(root)
    write_json_atomic(path, data)
    if emit_json_result(args, "reference.configure", 0, dry_run=False, plan=plan, data={"config": data}):
        return 0
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
    local_source: Optional[Path] = None
    source_revision: Optional[str] = None
    if args.allow_local:
        local_source = resolved_path(source)
        if not local_source.exists():
            raise ReferenceLibraryError(f"Local source does not exist: {local_source}")
        local_bundle = local_source.is_file()
        clone_source = str(local_source) if local_bundle else local_source.as_uri()
        stored_url = validate_public_url(args.canonical_url) if args.canonical_url else clone_source
        if local_source.is_dir():
            local_safe_directory = (local_source / ".git").as_posix()
            source_top_level = run_git(["rev-parse", "--show-toplevel"], cwd=local_source).stdout.strip()
            if Path(source_top_level).resolve(strict=False) != local_source.resolve(strict=False):
                raise ReferenceLibraryError(f"Local source is not a standalone Git repository: {local_source}")
            source_revision = run_git(["rev-parse", "HEAD"], cwd=local_source).stdout.strip()
    else:
        stored_url = validate_public_url(source)
    license_url = validate_license_url(args.license_url) if args.license_url else None

    validated_inputs: Dict[str, Any] = {
        "id": reference_id,
        "name": args.name or reference_id,
        "repositoryUrl": sanitize_url(stored_url),
        "category": category,
        "depth": args.depth,
        "tags": split_values(args.tag),
        "readFirst": split_values(args.read_first),
        "useWhen": split_values(args.use_when),
        "avoidWhen": split_values(args.avoid_when),
        "licenseUrl": license_url,
        "allowLocal": bool(args.allow_local),
        "sourceRevision": source_revision,
    }
    snapshot_targets = [destination, metadata_path]
    if local_source is not None:
        snapshot_targets.append(local_source)

    plan = write_plan(
        "reference.add",
        [
            {"kind": "git-clone", "target": str(destination), "summary": "clone 公开参考仓库，不执行其代码或 submodule"},
            {"kind": "write-json", "target": str(metadata_path), "summary": "写入 reference catalog"},
        ],
        snapshot_targets,
        validated_inputs,
    )
    if args.dry_run:
        if emit_json_result(
            args,
            "reference.add",
            0,
            dry_run=True,
            plan=plan,
            data={"id": reference_id, "destination": str(destination), "repositoryUrl": sanitize_url(stored_url)},
        ):
            return 0
        print(f"Reference root: {root} ({'configured' if configured else 'default'})")
        print(f"DryRun: would clone {sanitize_url(stored_url)}")
        print(f"DryRun: destination {destination}")
        print(f"DryRun: would write catalog {metadata_path}")
        print("DryRun: would not initialize submodules or execute repository code.")
        return 0

    validate_apply_plan(args, plan)
    if not args.json_output:
        print(f"Reference root: {root} ({'configured' if configured else 'default'})")
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
        timestamp = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
        metadata: Dict[str, Any] = {
            "schemaVersion": SCHEMA_VERSION,
            "id": reference_id,
            "name": args.name or reference_id,
            "repositoryUrl": sanitize_url(stored_url),
            "relativePath": destination.relative_to(root).as_posix(),
            "revision": head,
            "version": detect_version(destination),
            "branch": branch_process.stdout.strip() or "detached",
            "tags": validated_inputs["tags"],
            "trust": "source-only",
            "readFirst": read_first,
            "useWhen": validated_inputs["useWhen"],
            "avoidWhen": validated_inputs["avoidWhen"],
            "license": detect_license(destination),
            "licenseUrl": license_url,
            "notes": "",
            "source": {"kind": "public-git"},
            "createdAt": timestamp,
            "updatedAt": timestamp,
        }
        write_json_atomic(metadata_path, metadata)
    except Exception as exc:
        raise ReferenceLibraryError(
            f"Repository clone was preserved at {destination}, but catalog creation failed: {exc}"
        ) from exc

    if emit_json_result(
        args,
        "reference.add",
        0,
        dry_run=False,
        plan=plan,
        data={"id": reference_id, "destination": str(destination), "revision": head},
    ):
        return 0
    print(f"Added reference {reference_id}: {destination}")
    print(f"Revision: {head}")
    print(f"Catalog: {metadata_path}")
    return 0


def command_list(_: argparse.Namespace) -> int:
    config, path, configured = load_config()
    root = library_root(config)
    catalogs = load_catalogs(root)
    rows = []
    for reference_id, catalog in catalogs.items():
        state = repository_state(root, catalog)
        rows.append({"id": reference_id, "version": catalog.get("version") or "unknown", "state": state})
    if emit_json_result(_, "reference.list", 0, dry_run=False, data={"referenceRoot": str(root), "configured": configured, "references": rows}):
        return 0
    print(f"Reference root: {root} ({'configured' if configured else 'default'})")
    print(f"Config: {path}{'' if configured else ' (not written)'}")
    if not catalogs:
        print("No references registered.")
        return 0
    for row in rows:
        print(f"{row['id']}\t{row['state']['status']}\t{row['version']}\t{row['state']['path']}")
    return 0


def command_show(args: argparse.Namespace) -> int:
    reference_id = validate_reference_id(args.id)
    config, _, _ = load_config()
    root = library_root(config)
    data = load_catalogs(root).get(reference_id)
    if data is None:
        raise ReferenceLibraryError(f"reference catalog not found: {catalog_path(root, reference_id)}")
    data["state"] = repository_state(root, data)
    if emit_json_result(args, "reference.show", 0, dry_run=False, data={"reference": data}):
        return 0
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
    new_entry = {"id": reference_id, "purpose": args.purpose or "", "required": bool(args.required), "notes": ""}
    if entry is None:
        references.append(new_entry)
    else:
        entry.clear()
        entry.update(new_entry)
    references.sort(key=lambda item: str(item.get("id", "")))
    path = project_mapping_path(project)
    plan = write_plan(
        "reference.map",
        [{"kind": "write-json", "target": str(path), "summary": f"在项目中映射参考 {reference_id}"}],
        [path],
        {
            "project": str(project),
            "id": reference_id,
            "purpose": args.purpose or "",
            "required": bool(args.required),
        },
    )
    if args.dry_run:
        if emit_json_result(args, "reference.map", 0, dry_run=True, plan=plan, data={"mapping": mapping}):
            return 0
        print(f"DryRun: would map {reference_id} in {path}")
        return 0
    validate_apply_plan(args, plan)
    write_json_atomic(path, mapping)
    if emit_json_result(args, "reference.map", 0, dry_run=False, plan=plan, data={"mapping": mapping}):
        return 0
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
    plan = write_plan(
        "reference.unmap",
        [{"kind": "write-json", "target": str(path), "summary": f"从项目取消映射参考 {reference_id}"}],
        [path],
        {"project": str(project), "id": reference_id},
    )
    if args.dry_run:
        if emit_json_result(args, "reference.unmap", 0, dry_run=True, plan=plan, data={"mapping": mapping}):
            return 0
        print(f"DryRun: would unmap {reference_id} from {path}")
        return 0
    validate_apply_plan(args, plan)
    write_json_atomic(path, mapping)
    if emit_json_result(args, "reference.unmap", 0, dry_run=False, plan=plan, data={"mapping": mapping}):
        return 0
    print(f"Unmapped {reference_id}; global clone was preserved.")
    return 0


def command_context(args: argparse.Namespace) -> int:
    project = require_project(args.project)
    mapping = load_project_mapping(project)
    config, _, _ = load_config()
    root = library_root(config)
    catalogs = load_catalogs(root)
    content, required_unusable = context_markdown(project, root, mapping, catalogs)
    output = resolve_context_output(project, args.output)
    exit_code = 1 if required_unusable else 0
    plan = write_plan(
        "reference.context",
        [{"kind": "write-text", "target": str(output), "summary": "生成项目本地 Agent reference context"}],
        [output],
        {
            "project": str(project),
            "output": str(output),
            "contentSha256": hashlib.sha256(content.encode("utf-8")).hexdigest(),
        },
    )
    if args.dry_run:
        if emit_json_result(args, "reference.context", exit_code, dry_run=True, plan=plan, data={"output": str(output), "content": content}):
            return exit_code
        print(f"DryRun: would write reference context: {output}")
        print(content)
        return exit_code
    validate_apply_plan(args, plan)
    write_text_atomic(output, content)
    if emit_json_result(args, "reference.context", exit_code, dry_run=False, plan=plan, data={"output": str(output)}):
        return exit_code
    print(f"Wrote reference context: {output}")
    return exit_code


def command_status(args: argparse.Namespace, strict: bool) -> int:
    config, path, configured = load_config()
    root = library_root(config)
    catalogs = load_catalogs(root)
    rows, has_errors = status_rows(root, catalogs)
    if strict and not root.is_dir():
        has_errors = True

    mapped_ids = []
    unresolved = []
    if args.project:
        project = require_project(args.project)
        mapping = load_project_mapping(project)
        for entry in mapping["references"]:
            if not isinstance(entry, dict):
                has_errors = True
                continue
            reference_id = str(entry.get("id", ""))
            mapped_ids.append(reference_id)
            if reference_id not in catalogs:
                unresolved.append(reference_id)
                if entry.get("required") or strict:
                    has_errors = True
    exit_code = 1 if strict and has_errors else 0
    if emit_json_result(
        args,
        "reference.doctor" if strict else "reference.status",
        exit_code,
        dry_run=False,
        data={
            "configPath": str(path),
            "configured": configured,
            "referenceRoot": str(root),
            "rootExists": root.is_dir(),
            "references": rows,
            "projectMappings": mapped_ids,
            "unresolved": unresolved,
        },
    ):
        return exit_code
    print(f"Config: {path}{'' if configured else ' (default, not written)'}")
    print(f"Reference root: {root}")
    print(f"Root exists: {str(root.is_dir()).lower()}")
    if not rows:
        print("References: 0")
    for state in rows:
        print(f"Reference {state['id']}: {state['status']} ({state['path']})")
        for issue in state.get("issues", []):
            print(f"  - {issue}")
    for reference_id in unresolved:
        print(f"Project reference {reference_id}: unresolved")
    if args.project:
        print(f"Project mappings: {len(mapped_ids)}")
    return exit_code


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="AWZ Reference Library")
    subparsers = parser.add_subparsers(dest="command", required=True)

    def add_contract_options(command: argparse.ArgumentParser, writable: bool = False) -> None:
        command.add_argument("--json", dest="json_output", action="store_true", help="Emit the stable machine-readable result contract.")
        if writable:
            command.add_argument("--plan-hash", help="Apply only when this matches the prior DryRun planHash.")

    configure = subparsers.add_parser("configure", help="Configure the machine-level reference root.")
    configure.add_argument("--root", required=True)
    configure.add_argument("--depth", type=int, default=1)
    configure.add_argument("--dry-run", action="store_true")
    add_contract_options(configure, writable=True)
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
    add_contract_options(add, writable=True)
    add.set_defaults(handler=command_add)

    list_parser = subparsers.add_parser("list", help="List registered references.")
    add_contract_options(list_parser)
    list_parser.set_defaults(handler=command_list)

    show = subparsers.add_parser("show", help="Show one reference catalog and local state.")
    show.add_argument("--id", required=True)
    add_contract_options(show)
    show.set_defaults(handler=command_show)

    for name, handler in (("map", command_map), ("unmap", command_unmap)):
        command = subparsers.add_parser(name, help=f"{name.title()} a project reference.")
        command.add_argument("--project", required=True)
        command.add_argument("--id", required=True)
        if name == "map":
            command.add_argument("--purpose", default="")
            command.add_argument("--required", action="store_true")
        command.add_argument("--dry-run", action="store_true")
        add_contract_options(command, writable=True)
        command.set_defaults(handler=handler)

    context = subparsers.add_parser("context", help="Generate project-local AI reference context.")
    context.add_argument("--project", required=True)
    context.add_argument("--output")
    context.add_argument("--dry-run", action="store_true")
    add_contract_options(context, writable=True)
    context.set_defaults(handler=command_context)

    status = subparsers.add_parser("status", help="Show offline reference state.")
    status.add_argument("--project")
    add_contract_options(status)
    status.set_defaults(handler=lambda args: command_status(args, strict=False))

    doctor = subparsers.add_parser("doctor", help="Run strict offline validation.")
    doctor.add_argument("--project")
    add_contract_options(doctor)
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
