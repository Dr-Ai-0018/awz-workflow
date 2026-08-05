"""Project-level Reference Library mappings and generated Agent context."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any, Dict, Optional, Tuple

from .catalog import repository_state
from .config import SCHEMA_VERSION
from .errors import ReferenceLibraryError
from .paths import is_within, resolved_path
from .storage import read_json


def project_mapping_path(project: Path) -> Path:
    return project / ".awz" / "references.json"


def load_project_mapping(project: Path, allow_missing: bool = False) -> Dict[str, Any]:
    path = project_mapping_path(project)
    if not path.exists() and allow_missing:
        return {"schemaVersion": SCHEMA_VERSION, "references": []}
    data = read_json(path, "project reference mapping")
    if data.get("schemaVersion") not in (1, SCHEMA_VERSION) or not isinstance(data.get("references"), list):
        raise ReferenceLibraryError(f"Invalid project reference mapping schema: {path}")
    normalized = {**data, "schemaVersion": SCHEMA_VERSION, "references": []}
    for entry in data["references"]:
        if not isinstance(entry, dict):
            normalized["references"].append(entry)
            continue
        normalized["references"].append({**entry, "notes": entry.get("notes", "")})
    return normalized


def require_project(value: str) -> Path:
    project = resolved_path(value)
    if not project.is_dir():
        raise ReferenceLibraryError(f"Project directory does not exist: {project}")
    return project


def context_markdown(
    project: Path, root: Path, mapping: Dict[str, Any], catalogs: Dict[str, Dict[str, Any]]
) -> Tuple[str, bool]:
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


def resolve_context_output(project: Path, output_value: Optional[str]) -> Path:
    if output_value:
        requested_output = Path(os.path.expandvars(output_value)).expanduser()
        output = resolved_path(str(requested_output if requested_output.is_absolute() else project / requested_output))
    else:
        output = project / "docs" / "agent-room" / "reference-context.md"
    if not is_within(output, project):
        raise ReferenceLibraryError(f"Context output must stay inside the project: {output}")
    return output
