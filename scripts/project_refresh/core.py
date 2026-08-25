"""Plan and apply a safe refresh of AWZ-managed project files."""

from __future__ import annotations

import hashlib
import re
import shutil
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from reference_library.contracts import build_plan, snapshot_paths
from reference_library.errors import ReferenceLibraryError
from reference_library.paths import is_within
from reference_library.storage import read_json, write_bytes_atomic, write_json_atomic
from reference_library.transactions import ReferenceTransaction


MANIFEST_SCHEMA_VERSION = 1
MANIFEST_RELATIVE_PATH = Path("docs/agent-room/.awz-manifest.json")


@dataclass(frozen=True)
class ManagedTemplate:
    source: str
    destination: str


MANAGED_TEMPLATES: Tuple[ManagedTemplate, ...] = (
    ManagedTemplate("AGENTS.md", "AGENTS.md"),
    ManagedTemplate("CLAUDE.md", "CLAUDE.md"),
    ManagedTemplate("docs-layout.md", "docs/README.md"),
    ManagedTemplate("agent-onboarding.md", "docs/agent-room/onboarding.md"),
    ManagedTemplate("room-ledger.py", "docs/agent-room/room-ledger.py"),
    ManagedTemplate("guides/repository-hygiene.md", "docs/agent-room/guides/repository-hygiene.md"),
    ManagedTemplate("guides/git-workflow.md", "docs/agent-room/guides/git-workflow.md"),
    ManagedTemplate("guides/verification.md", "docs/agent-room/guides/verification.md"),
    ManagedTemplate("guides/file-search.md", "docs/agent-room/guides/file-search.md"),
    ManagedTemplate("guides/code-architecture.md", "docs/agent-room/guides/code-architecture.md"),
    ManagedTemplate("guides/frontend/visual-composition.md", "docs/agent-room/guides/frontend/visual-composition.md"),
    ManagedTemplate("guides/frontend/motion-and-interaction.md", "docs/agent-room/guides/frontend/motion-and-interaction.md"),
    ManagedTemplate("guides/frontend/responsive-and-verification.md", "docs/agent-room/guides/frontend/responsive-and-verification.md"),
    ManagedTemplate("guides/blockers-and-safety.md", "docs/agent-room/guides/blockers-and-safety.md"),
    ManagedTemplate("guides/review.md", "docs/agent-room/guides/review.md"),
    ManagedTemplate("guides/room-ledger.md", "docs/agent-room/guides/room-ledger.md"),
    ManagedTemplate("handoff.template.md", "docs/agent-room/handoffs/handoff.template.md"),
    ManagedTemplate("review-checklist.template.md", "docs/agent-room/reviews/review-checklist.template.md"),
    ManagedTemplate("decision-record.template.md", "docs/agent-room/decisions/decision-record.template.md"),
    ManagedTemplate("release-checklist.template.md", "docs/plans/release-checklist.template.md"),
    ManagedTemplate("temp-layout.md", "temp/README.md"),
)


def sha256_bytes(content: bytes) -> str:
    return hashlib.sha256(content).hexdigest()


def require_safe_roots(workflow_root: Path, target: Path) -> Tuple[Path, Path, Path]:
    try:
        workflow = workflow_root.resolve(strict=True)
        project = target.resolve(strict=True)
        template_root = (workflow / "templates" / "project").resolve(strict=True)
    except FileNotFoundError as exc:
        raise ReferenceLibraryError(f"Refresh path does not exist: {exc.filename}") from exc
    if not project.is_dir():
        raise ReferenceLibraryError(f"Refresh target is not a directory: {project}")
    if project == Path(project.anchor).resolve(strict=False) or project == Path.home().resolve(strict=False):
        raise ReferenceLibraryError(f"Refresh target is too broad: {project}")
    if project == workflow:
        raise ReferenceLibraryError("Refresh target cannot be the AWZ Workflow source directory.")
    if not template_root.is_dir():
        raise ReferenceLibraryError(f"AWZ project templates are missing: {template_root}")
    if not (workflow / "VERSION").is_file():
        raise ReferenceLibraryError(f"AWZ VERSION is missing: {workflow / 'VERSION'}")
    if not (project / ".awz" / "references.json").is_file():
        raise ReferenceLibraryError(
            "Target does not contain .awz/references.json. Use the Existing initializer before refresh."
        )
    return workflow, project, template_root


def safe_child(root: Path, relative: str, label: str) -> Path:
    candidate = (root / Path(relative)).resolve(strict=False)
    if not is_within(candidate, root):
        raise ReferenceLibraryError(f"{label} escapes its allowed root: {candidate}")
    return candidate


def load_manifest(path: Path) -> Dict[str, Any]:
    if not path.exists():
        return {"schemaVersion": MANIFEST_SCHEMA_VERSION, "workflowVersion": None, "files": []}
    manifest = read_json(path, "AWZ managed-file manifest")
    if manifest.get("schemaVersion") != MANIFEST_SCHEMA_VERSION or not isinstance(manifest.get("files"), list):
        raise ReferenceLibraryError(f"Unsupported AWZ managed-file manifest: {path}")
    seen_paths = set()
    for entry in manifest["files"]:
        if not isinstance(entry, dict):
            raise ReferenceLibraryError(f"Invalid managed-file manifest entry: {path}")
        source = entry.get("source")
        destination = entry.get("path")
        applied_hash = entry.get("appliedSha256")
        if not isinstance(source, str) or not source or not isinstance(destination, str) or not destination:
            raise ReferenceLibraryError(f"Managed-file manifest entry is missing source/path: {path}")
        relative_path = Path(destination)
        if relative_path.is_absolute() or any(part in ("", ".", "..") for part in relative_path.parts):
            raise ReferenceLibraryError(f"Unsafe managed-file manifest path: {destination}")
        if destination in seen_paths:
            raise ReferenceLibraryError(f"Duplicate managed-file manifest path: {destination}")
        source_path = Path(source)
        if source_path.is_absolute() or any(part in ("", ".", "..") for part in source_path.parts):
            raise ReferenceLibraryError(f"Unsafe managed-file manifest source: {source}")
        if not isinstance(applied_hash, str) or not re.fullmatch(r"[0-9a-f]{64}", applied_hash):
            raise ReferenceLibraryError(f"Invalid appliedSha256 for managed file: {destination}")
        seen_paths.add(destination)
    return manifest


def diff_stats(current: Optional[bytes], desired: bytes) -> Dict[str, int]:
    if current is None:
        return {"addedLines": len(desired.decode("utf-8", errors="replace").splitlines()), "removedLines": 0}
    current_lines = current.decode("utf-8", errors="replace").splitlines()
    desired_lines = desired.decode("utf-8", errors="replace").splitlines()
    common_prefix = 0
    for current_line, desired_line in zip(current_lines, desired_lines):
        if current_line != desired_line:
            break
        common_prefix += 1
    common_suffix = 0
    while (
        common_suffix < len(current_lines) - common_prefix
        and common_suffix < len(desired_lines) - common_prefix
        and current_lines[-(common_suffix + 1)] == desired_lines[-(common_suffix + 1)]
    ):
        common_suffix += 1
    return {
        "addedLines": max(0, len(desired_lines) - common_prefix - common_suffix),
        "removedLines": max(0, len(current_lines) - common_prefix - common_suffix),
    }


def scan_refresh(workflow_root: Path, target: Path) -> Dict[str, Any]:
    workflow, project, template_root = require_safe_roots(workflow_root, target)
    manifest_path = safe_child(project, MANIFEST_RELATIVE_PATH.as_posix(), "Manifest path")
    manifest = load_manifest(manifest_path)
    prior_entries = {
        str(entry.get("path")): entry
        for entry in manifest["files"]
        if isinstance(entry, dict) and isinstance(entry.get("path"), str)
    }
    managed_destinations = {managed.destination for managed in MANAGED_TEMPLATES}
    version = (workflow / "VERSION").read_text(encoding="utf-8-sig").strip()
    files: List[Dict[str, Any]] = []
    desired_entries: List[Dict[str, str]] = [
        {
            "source": str(entry["source"]),
            "path": str(entry["path"]),
            "appliedSha256": str(entry["appliedSha256"]),
        }
        for entry in manifest["files"]
        if str(entry["path"]) not in managed_destinations
    ]
    snapshot_targets: List[Path] = [manifest_path]
    changes: List[Dict[str, Any]] = []
    blocked_by: List[str] = []

    for managed in MANAGED_TEMPLATES:
        source = safe_child(template_root, managed.source, "Template source")
        destination = safe_child(project, managed.destination, "Managed destination")
        if not source.is_file():
            raise ReferenceLibraryError(f"Managed template source is missing: {managed.source}")
        desired_content = source.read_bytes()
        desired_hash = sha256_bytes(desired_content)
        unsafe_destination = destination.exists() and (destination.is_symlink() or not destination.is_file())
        current_content = destination.read_bytes() if destination.is_file() and not destination.is_symlink() else None
        current_hash = sha256_bytes(current_content) if current_content is not None else None
        prior = prior_entries.get(managed.destination)
        baseline_hash = str(prior.get("appliedSha256")) if isinstance(prior, dict) else None

        if unsafe_destination:
            classification = "conflict"
            blocked_by.append(f"Managed destination is not a regular file: {managed.destination}")
        elif current_content is None:
            classification = "create"
        elif current_hash == desired_hash:
            classification = "unchanged" if baseline_hash == desired_hash else "adopt"
        elif baseline_hash and current_hash == baseline_hash:
            classification = "update"
        else:
            classification = "conflict"
            blocked_by.append(f"Local modification requires review: {managed.destination}")

        entry = {
            "source": managed.source,
            "path": managed.destination,
            "classification": classification,
            "baselineSha256": baseline_hash,
            "currentSha256": current_hash,
            "desiredSha256": desired_hash,
            "diff": diff_stats(current_content, desired_content),
        }
        files.append(entry)
        snapshot_targets.extend([source, destination])

        if classification != "conflict":
            desired_entries.append(
                {"source": managed.source, "path": managed.destination, "appliedSha256": desired_hash}
            )
        elif isinstance(prior, dict):
            desired_entries.append(
                {
                    "source": str(prior.get("source", managed.source)),
                    "path": managed.destination,
                    "appliedSha256": str(prior.get("appliedSha256", "")),
                }
            )

        if classification in ("create", "update"):
            changes.append(
                {
                    "kind": f"{classification}-managed-file",
                    "target": str(destination),
                    "path": managed.destination,
                    "summary": f"{classification} AWZ-managed file {managed.destination}",
                    "desiredSha256": desired_hash,
                    **entry["diff"],
                }
            )

    desired_manifest = {
        "schemaVersion": MANIFEST_SCHEMA_VERSION,
        "workflowVersion": version,
        "files": sorted(desired_entries, key=lambda item: item["path"]),
    }
    stable_manifest = {
        "schemaVersion": manifest.get("schemaVersion"),
        "workflowVersion": manifest.get("workflowVersion"),
        "files": sorted(manifest.get("files", []), key=lambda item: str(item.get("path", ""))),
    }
    manifest_changed = desired_manifest != stable_manifest
    if manifest_changed:
        changes.append(
            {
                "kind": "write-manifest",
                "target": str(manifest_path),
                "path": MANIFEST_RELATIVE_PATH.as_posix(),
                "summary": "Record AWZ-managed file ownership and applied hashes",
            }
        )

    plan = build_plan(
        "project.refresh",
        changes,
        snapshot_paths(snapshot_targets),
        validated_inputs={
            "workflowRoot": str(workflow),
            "target": str(project),
            "workflowVersion": version,
        },
        blocked_by=blocked_by,
        recovery=["Resolve local conflicts, then run refresh DryRun again."] if blocked_by else [],
    )
    return {
        "workflowRoot": workflow,
        "target": project,
        "templateRoot": template_root,
        "manifestPath": manifest_path,
        "manifest": desired_manifest,
        "manifestChanged": manifest_changed,
        "files": files,
        "plan": plan,
    }


def apply_refresh(scan: Dict[str, Any], supplied_hash: str) -> Optional[ReferenceTransaction]:
    from reference_library.contracts import require_matching_plan

    scan = scan_refresh(scan["workflowRoot"], scan["target"])
    plan = scan["plan"]
    require_matching_plan(plan, supplied_hash)
    if plan["blockedBy"]:
        raise ReferenceLibraryError(
            "Refresh is blocked by local modifications.",
            recovery=plan["recovery"],
        )
    if not plan["changes"]:
        return None

    target: Path = scan["target"]
    template_root: Path = scan["templateRoot"]
    transaction_root = safe_child(target, "docs/agent-room", "Refresh transaction root")
    transaction = ReferenceTransaction(transaction_root, "project.refresh", plan)
    backup_root = safe_child(
        target,
        f"docs/agent-room/refresh-backups/{transaction.transaction_id}",
        "Refresh backup root",
    )
    change_index = 0
    try:
        transaction.begin_apply()
        for file_state in scan["files"]:
            if file_state["classification"] not in ("create", "update"):
                continue
            source = safe_child(template_root, file_state["source"], "Template source")
            destination = safe_child(target, file_state["path"], "Managed destination")
            if destination.exists():
                backup = safe_child(backup_root, file_state["path"], "Refresh backup")
                backup.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(destination, backup)
            write_bytes_atomic(destination, source.read_bytes())
            transaction.complete_action(change_index)
            change_index += 1

        if scan["manifestChanged"]:
            write_json_atomic(scan["manifestPath"], scan["manifest"])
            transaction.complete_action(change_index)
        transaction.complete()
        return transaction
    except Exception as exc:
        recovery = [
            f"Review the transaction record at {transaction.path}.",
            f"Restore overwritten files from {backup_root} where backups exist.",
            "Re-run refresh DryRun after inspecting completed and remaining actions.",
        ]
        try:
            transaction.fail(exc, recovery)
        except Exception as transaction_error:
            raise ReferenceLibraryError(
                f"{exc}; refresh transaction update also failed: {transaction_error}",
                recovery=recovery,
            ) from exc
        raise ReferenceLibraryError(
            str(exc), recovery=recovery, transaction=transaction.summary()
        ) from exc
