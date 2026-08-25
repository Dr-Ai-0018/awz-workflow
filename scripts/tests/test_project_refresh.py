from __future__ import annotations

import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT_ROOT = Path(__file__).resolve().parents[1]
REPOSITORY_ROOT = SCRIPT_ROOT.parent
if str(SCRIPT_ROOT) not in sys.path:
    sys.path.insert(0, str(SCRIPT_ROOT))

from project_refresh.core import (  # noqa: E402
    MANAGED_TEMPLATES,
    apply_refresh,
    scan_refresh,
)
from reference_library.errors import ReferenceLibraryError  # noqa: E402


class ProjectRefreshTests(unittest.TestCase):
    def make_fixture(self, root: Path) -> tuple[Path, Path]:
        workflow = root / "workflow"
        target = root / "project"
        shutil.copytree(REPOSITORY_ROOT / "templates", workflow / "templates")
        shutil.copy2(REPOSITORY_ROOT / "VERSION", workflow / "VERSION")
        (target / ".awz").mkdir(parents=True)
        (target / ".awz" / "references.json").write_text(
            '{"schemaVersion":1,"references":[]}\n', encoding="utf-8"
        )
        return workflow, target

    def apply_initial_refresh(self, workflow: Path, target: Path):
        scan = scan_refresh(workflow, target)
        self.assertFalse(scan["plan"]["blockedBy"])
        transaction = apply_refresh(scan, scan["plan"]["planHash"])
        self.assertIsNotNone(transaction)
        return transaction

    def test_first_refresh_creates_managed_files_and_stable_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            workflow, target = self.make_fixture(Path(directory))
            protected = {
                "README.md": "custom project README\n",
                "LICENSE": "custom project license\n",
                "docs/references/README.md": "custom project context\n",
                "docs/agent-room/status.md": "custom project status\n",
                "docs/agent-room/guides/collaboration.md": "custom collaboration strategy\n",
                "docs/agent-room/guides/frontend.md": "custom frontend profile\n",
            }
            for relative, content in protected.items():
                path = target / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content, encoding="utf-8")
            transaction = self.apply_initial_refresh(workflow, target)

            self.assertEqual("completed", transaction.summary()["state"])
            for managed in MANAGED_TEMPLATES:
                self.assertEqual(
                    (workflow / "templates" / "project" / managed.source).read_bytes(),
                    (target / managed.destination).read_bytes(),
                )
            manifest_path = target / "docs" / "agent-room" / ".awz-manifest.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            self.assertEqual(len(MANAGED_TEMPLATES), len(manifest["files"]))
            for relative, content in protected.items():
                self.assertEqual(content, (target / relative).read_text(encoding="utf-8"))

            second_scan = scan_refresh(workflow, target)
            self.assertEqual([], second_scan["plan"]["changes"])
            self.assertTrue(all(item["classification"] == "unchanged" for item in second_scan["files"]))

    def test_template_update_overwrites_unchanged_managed_file_with_backup(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            workflow, target = self.make_fixture(Path(directory))
            self.apply_initial_refresh(workflow, target)
            source = workflow / "templates" / "project" / "AGENTS.md"
            source.write_text(source.read_text(encoding="utf-8") + "\nnew workflow rule\n", encoding="utf-8")

            scan = scan_refresh(workflow, target)
            agents = next(item for item in scan["files"] if item["path"] == "AGENTS.md")
            self.assertEqual("update", agents["classification"])
            transaction = apply_refresh(scan, scan["plan"]["planHash"])

            self.assertEqual(source.read_bytes(), (target / "AGENTS.md").read_bytes())
            backup = (
                target
                / "docs"
                / "agent-room"
                / "refresh-backups"
                / transaction.transaction_id
                / "AGENTS.md"
            )
            self.assertTrue(backup.is_file())
            self.assertNotEqual(source.read_bytes(), backup.read_bytes())

    def test_local_modification_blocks_the_whole_refresh(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            workflow, target = self.make_fixture(Path(directory))
            self.apply_initial_refresh(workflow, target)
            agents = target / "AGENTS.md"
            agents.write_text(agents.read_text(encoding="utf-8") + "\nlocal project rule\n", encoding="utf-8")
            onboarding = target / "docs" / "agent-room" / "onboarding.md"
            before = onboarding.read_bytes()

            scan = scan_refresh(workflow, target)
            agents_state = next(item for item in scan["files"] if item["path"] == "AGENTS.md")
            self.assertEqual("conflict", agents_state["classification"])
            self.assertTrue(scan["plan"]["blockedBy"])
            with self.assertRaisesRegex(ReferenceLibraryError, "blocked by local modifications"):
                apply_refresh(scan, scan["plan"]["planHash"])
            self.assertEqual(before, onboarding.read_bytes())

    def test_apply_rechecks_live_state_and_rejects_stale_plan(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            workflow, target = self.make_fixture(Path(directory))
            self.apply_initial_refresh(workflow, target)
            source = workflow / "templates" / "project" / "AGENTS.md"
            source.write_text(source.read_text(encoding="utf-8") + "\nnew workflow rule\n", encoding="utf-8")
            scan = scan_refresh(workflow, target)
            target_agents = target / "AGENTS.md"
            target_agents.write_text(target_agents.read_text(encoding="utf-8") + "\nraced local edit\n", encoding="utf-8")

            with self.assertRaisesRegex(ReferenceLibraryError, "Plan is stale"):
                apply_refresh(scan, scan["plan"]["planHash"])

    def test_uninitialized_target_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            workflow = root / "workflow"
            target = root / "project"
            shutil.copytree(REPOSITORY_ROOT / "templates", workflow / "templates")
            shutil.copy2(REPOSITORY_ROOT / "VERSION", workflow / "VERSION")
            target.mkdir()
            with self.assertRaisesRegex(ReferenceLibraryError, "Existing initializer"):
                scan_refresh(workflow, target)

    def test_directory_at_managed_destination_is_blocked(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            workflow, target = self.make_fixture(Path(directory))
            (target / "AGENTS.md").mkdir()
            scan = scan_refresh(workflow, target)
            agents = next(item for item in scan["files"] if item["path"] == "AGENTS.md")
            self.assertEqual("conflict", agents["classification"])
            self.assertTrue(scan["plan"]["blockedBy"])

    def test_corrupt_manifest_is_rejected_without_writes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            workflow, target = self.make_fixture(Path(directory))
            manifest = target / "docs" / "agent-room" / ".awz-manifest.json"
            manifest.parent.mkdir(parents=True)
            manifest.write_text(
                json.dumps(
                    {
                        "schemaVersion": 1,
                        "workflowVersion": "0.2.0",
                        "files": [{"source": "AGENTS.md", "path": "../escape", "appliedSha256": "bad"}],
                    }
                ),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ReferenceLibraryError, "Unsafe managed-file manifest path"):
                scan_refresh(workflow, target)

    def test_unknown_safe_manifest_entry_is_preserved(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            workflow, target = self.make_fixture(Path(directory))
            self.apply_initial_refresh(workflow, target)
            manifest_path = target / "docs" / "agent-room" / ".awz-manifest.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["files"].append(
                {
                    "source": "future-guide.md",
                    "path": "docs/agent-room/guides/future-guide.md",
                    "appliedSha256": "a" * 64,
                }
            )
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

            scan = scan_refresh(workflow, target)
            apply_refresh(scan, scan["plan"]["planHash"])
            refreshed = json.loads(manifest_path.read_text(encoding="utf-8"))
            future = next(item for item in refreshed["files"] if item["path"].endswith("future-guide.md"))
            self.assertEqual("a" * 64, future["appliedSha256"])


if __name__ == "__main__":
    unittest.main()
