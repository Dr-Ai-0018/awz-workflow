from __future__ import annotations

import json
import importlib.util
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

SCRIPT_ROOT = Path(__file__).resolve().parents[1]
if str(SCRIPT_ROOT) not in sys.path:
    sys.path.insert(0, str(SCRIPT_ROOT))

CLI = SCRIPT_ROOT / "reference-library.py"


class ReferenceCliTransactionTests(unittest.TestCase):
    def run_cli(
        self,
        config_dir: Path,
        *arguments: str,
        reference_root: Path | None = None,
    ) -> subprocess.CompletedProcess[str]:
        environment = os.environ.copy()
        environment["AWZ_CONFIG_DIR"] = str(config_dir)
        if reference_root is not None:
            environment["AWZ_REFERENCE_ROOT"] = str(reference_root)
        environment["PYTHONUTF8"] = "1"
        return subprocess.run(
            [sys.executable, str(CLI), *arguments],
            cwd=str(SCRIPT_ROOT.parent),
            env=environment,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            errors="replace",
            check=False,
        )

    def test_configure_json_apply_writes_completed_transaction(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory)
            config_dir = fixture / "config"
            reference_root = fixture / "references"
            preview = self.run_cli(
                config_dir,
                "configure",
                "--root",
                str(reference_root),
                "--dry-run",
                "--json",
            )
            self.assertEqual(0, preview.returncode, preview.stderr)
            preview_result = json.loads(preview.stdout)
            plan_hash = preview_result["plan"]["planHash"]

            stale = self.run_cli(
                config_dir,
                "configure",
                "--root",
                str(reference_root),
                "--json",
                "--plan-hash",
                "0" * 64,
            )
            self.assertEqual(1, stale.returncode)
            stale_result = json.loads(stale.stdout)
            self.assertTrue(stale_result["blockedBy"])
            self.assertFalse(reference_root.exists())

            applied = self.run_cli(
                config_dir,
                "configure",
                "--root",
                str(reference_root),
                "--json",
                "--plan-hash",
                plan_hash,
            )
            self.assertEqual(0, applied.returncode, applied.stderr)
            applied_result = json.loads(applied.stdout)
            transaction = applied_result["data"]["transaction"]
            transaction_path = Path(transaction["path"])

            self.assertEqual("completed", transaction["state"])
            self.assertTrue(transaction_path.is_file())
            record = json.loads(transaction_path.read_text(encoding="utf-8"))
            self.assertEqual("reference.configure", record["operation"])
            self.assertEqual(plan_hash, record["planHash"])
            self.assertEqual(2, len(record["completed"]))
            self.assertEqual([], record["remaining"])
            self.assertTrue((config_dir / "config.json").is_file())

    def test_add_local_fixture_requires_preview_and_records_transaction(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory)
            config_dir = fixture / "config"
            reference_root = fixture / "references"
            source = fixture / "source"
            source.mkdir()
            (source / "README.md").write_text("offline fixture\n", encoding="utf-8")
            subprocess.run(["git", "init", "-q"], cwd=source, check=True)
            subprocess.run(["git", "config", "user.email", "awz-test@example.com"], cwd=source, check=True)
            subprocess.run(["git", "config", "user.name", "AWZ Test"], cwd=source, check=True)
            subprocess.run(["git", "add", "README.md"], cwd=source, check=True)
            subprocess.run(["git", "commit", "-qm", "fixture"], cwd=source, check=True)

            preview = self.run_cli(
                config_dir,
                "add",
                "--id",
                "offline-fixture",
                "--url",
                str(source),
                "--allow-local",
                "--dry-run",
                "--json",
                reference_root=reference_root,
            )
            self.assertEqual(0, preview.returncode, preview.stderr)
            preview_result = json.loads(preview.stdout)
            self.assertTrue(preview_result["dryRun"])
            self.assertEqual("reference.add", preview_result["operation"])
            plan_hash = preview_result["plan"]["planHash"]
            destination = Path(preview_result["data"]["destination"])
            self.assertFalse(destination.exists())
            self.assertFalse(reference_root.exists())

            applied = self.run_cli(
                config_dir,
                "add",
                "--id",
                "offline-fixture",
                "--url",
                str(source),
                "--allow-local",
                "--json",
                "--plan-hash",
                plan_hash,
                reference_root=reference_root,
            )
            self.assertEqual(0, applied.returncode, applied.stderr)
            applied_result = json.loads(applied.stdout)
            self.assertEqual("completed", applied_result["data"]["transaction"]["state"])
            self.assertTrue(destination.is_dir())
            catalog = reference_root / "catalog" / "offline-fixture.json"
            self.assertTrue(catalog.is_file())
            self.assertEqual("offline-fixture", json.loads(catalog.read_text(encoding="utf-8"))["id"])

            duplicate = self.run_cli(
                config_dir,
                "add",
                "--id",
                "offline-fixture",
                "--url",
                str(source),
                "--allow-local",
                "--dry-run",
                "--json",
                reference_root=reference_root,
            )
            self.assertEqual(1, duplicate.returncode)
            self.assertTrue(json.loads(duplicate.stdout)["blockedBy"])

    def test_add_preserves_clone_when_catalog_write_fails(self) -> None:
        spec = importlib.util.spec_from_file_location("awz_reference_cli", CLI)
        self.assertIsNotNone(spec)
        self.assertIsNotNone(spec.loader)
        cli = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cli)

        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory)
            config_dir = fixture / "config"
            reference_root = fixture / "references"
            source = fixture / "source"
            source.mkdir()
            (source / "README.md").write_text("offline fixture\n", encoding="utf-8")
            subprocess.run(["git", "init", "-q"], cwd=source, check=True)
            subprocess.run(["git", "config", "user.email", "awz-test@example.com"], cwd=source, check=True)
            subprocess.run(["git", "config", "user.name", "AWZ Test"], cwd=source, check=True)
            subprocess.run(["git", "add", "README.md"], cwd=source, check=True)
            subprocess.run(["git", "commit", "-qm", "fixture"], cwd=source, check=True)
            args = type("Args", (), {
                "id": "broken-fixture",
                "name": None,
                "url": str(source),
                "category": "general",
                "depth": 1,
                "tag": None,
                "read_first": None,
                "use_when": None,
                "avoid_when": None,
                "license_url": None,
                "canonical_url": None,
                "allow_local": True,
                "dry_run": False,
                "json_output": False,
                "plan_hash": None,
            })()

            with mock.patch.dict(os.environ, {"AWZ_CONFIG_DIR": str(config_dir), "AWZ_REFERENCE_ROOT": str(reference_root)}, clear=False):
                with mock.patch.object(cli, "write_json_atomic", side_effect=OSError("catalog fixture failure")):
                    with self.assertRaises(cli.ReferenceLibraryError) as raised:
                        cli.command_add(args)

            self.assertIn("clone was preserved", str(raised.exception))
            destination = reference_root / "repos" / "general" / "broken-fixture"
            self.assertTrue(destination.is_dir())
            transaction_files = list((reference_root / "logs" / "transactions").glob("*.json"))
            self.assertEqual(1, len(transaction_files))
            record = json.loads(transaction_files[0].read_text(encoding="utf-8"))
            self.assertEqual("failed", record["state"])
            self.assertEqual(2, len(record["completed"]))
            self.assertEqual(1, len(record["remaining"]))
            self.assertTrue(any("preserved repository" in item for item in record["recovery"]))

    def test_check_update_reports_fast_forward_and_dirty_block(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory)
            config_dir = fixture / "config"
            reference_root = fixture / "references"
            source = fixture / "source"
            source.mkdir()
            readme = source / "README.md"
            readme.write_text("initial\n", encoding="utf-8")
            subprocess.run(["git", "init", "-q"], cwd=source, check=True)
            subprocess.run(["git", "config", "user.email", "awz-test@example.com"], cwd=source, check=True)
            subprocess.run(["git", "config", "user.name", "AWZ Test"], cwd=source, check=True)
            subprocess.run(["git", "add", "README.md"], cwd=source, check=True)
            subprocess.run(["git", "commit", "-qm", "initial"], cwd=source, check=True)

            preview = self.run_cli(
                config_dir,
                "add",
                "--id",
                "update-fixture",
                "--url",
                str(source),
                "--allow-local",
                "--dry-run",
                "--json",
                reference_root=reference_root,
            )
            self.assertEqual(0, preview.returncode, preview.stderr)
            plan_hash = json.loads(preview.stdout)["plan"]["planHash"]
            applied = self.run_cli(
                config_dir,
                "add",
                "--id",
                "update-fixture",
                "--url",
                str(source),
                "--allow-local",
                "--json",
                "--plan-hash",
                plan_hash,
                reference_root=reference_root,
            )
            self.assertEqual(0, applied.returncode, applied.stderr)

            readme.write_text("updated upstream\n", encoding="utf-8")
            subprocess.run(["git", "add", "README.md"], cwd=source, check=True)
            subprocess.run(["git", "commit", "-qm", "upstream"], cwd=source, check=True)
            checked = self.run_cli(
                config_dir,
                "check-update",
                "--id",
                "update-fixture",
                "--remote",
                "--json",
                reference_root=reference_root,
            )
            self.assertEqual(0, checked.returncode, checked.stderr)
            data = json.loads(checked.stdout)["data"]
            self.assertEqual("update-available", data["status"])
            self.assertEqual("fast-forward", data["relation"])
            self.assertEqual(1, data["behind"])
            self.assertFalse(data["dirty"])

            destination = reference_root / "repos" / "general" / "update-fixture"
            (destination / "local.txt").write_text("dirty\n", encoding="utf-8")
            dirty = self.run_cli(
                config_dir,
                "check-update",
                "--id",
                "update-fixture",
                "--remote",
                "--json",
                reference_root=reference_root,
            )
            self.assertEqual(1, dirty.returncode)
            dirty_result = json.loads(dirty.stdout)
            self.assertIn("repository worktree is dirty", dirty_result["blockedBy"])

    def test_update_requires_fresh_plan_and_fast_forwards_only(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory)
            config_dir = fixture / "config"
            reference_root = fixture / "references"
            source = fixture / "source"
            source.mkdir()
            readme = source / "README.md"
            readme.write_text("initial\n", encoding="utf-8")
            subprocess.run(["git", "init", "-q"], cwd=source, check=True)
            subprocess.run(["git", "config", "user.email", "awz-test@example.com"], cwd=source, check=True)
            subprocess.run(["git", "config", "user.name", "AWZ Test"], cwd=source, check=True)
            subprocess.run(["git", "add", "README.md"], cwd=source, check=True)
            subprocess.run(["git", "commit", "-qm", "initial"], cwd=source, check=True)

            add_preview = self.run_cli(
                config_dir,
                "add", "--id", "update-apply-fixture", "--url", str(source), "--allow-local", "--dry-run", "--json",
                reference_root=reference_root,
            )
            add_hash = json.loads(add_preview.stdout)["plan"]["planHash"]
            added = self.run_cli(
                config_dir,
                "add", "--id", "update-apply-fixture", "--url", str(source), "--allow-local", "--json", "--plan-hash", add_hash,
                reference_root=reference_root,
            )
            self.assertEqual(0, added.returncode, added.stderr)
            destination = reference_root / "repos" / "general" / "update-apply-fixture"
            old_head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=destination, check=True, text=True, stdout=subprocess.PIPE).stdout.strip()

            readme.write_text("upstream one\n", encoding="utf-8")
            subprocess.run(["git", "add", "README.md"], cwd=source, check=True)
            subprocess.run(["git", "commit", "-qm", "upstream-one"], cwd=source, check=True)
            preview = self.run_cli(
                config_dir,
                "update", "--id", "update-apply-fixture", "--dry-run", "--json", reference_root=reference_root,
            )
            self.assertEqual(0, preview.returncode, preview.stderr)
            preview_result = json.loads(preview.stdout)
            self.assertEqual("reference.update", preview_result["operation"])
            self.assertEqual("update-available", preview_result["data"]["status"])
            update_hash = preview_result["plan"]["planHash"]
            self.assertEqual(old_head, subprocess.run(["git", "rev-parse", "HEAD"], cwd=destination, check=True, text=True, stdout=subprocess.PIPE).stdout.strip())

            readme.write_text("upstream two\n", encoding="utf-8")
            subprocess.run(["git", "add", "README.md"], cwd=source, check=True)
            subprocess.run(["git", "commit", "-qm", "upstream-two"], cwd=source, check=True)
            stale = self.run_cli(
                config_dir,
                "update", "--id", "update-apply-fixture", "--json", "--plan-hash", update_hash, reference_root=reference_root,
            )
            self.assertEqual(1, stale.returncode)
            self.assertIn("Plan is stale", json.loads(stale.stdout)["blockedBy"][0])
            self.assertEqual(old_head, subprocess.run(["git", "rev-parse", "HEAD"], cwd=destination, check=True, text=True, stdout=subprocess.PIPE).stdout.strip())

            fresh_preview = self.run_cli(
                config_dir,
                "update", "--id", "update-apply-fixture", "--dry-run", "--json", reference_root=reference_root,
            )
            fresh_hash = json.loads(fresh_preview.stdout)["plan"]["planHash"]
            applied = self.run_cli(
                config_dir,
                "update", "--id", "update-apply-fixture", "--json", "--plan-hash", fresh_hash, reference_root=reference_root,
            )
            self.assertEqual(0, applied.returncode, applied.stderr)
            result = json.loads(applied.stdout)
            self.assertEqual("completed", result["data"]["transaction"]["state"])
            new_head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=destination, check=True, text=True, stdout=subprocess.PIPE).stdout.strip()
            self.assertNotEqual(old_head, new_head)
            catalog = json.loads((reference_root / "catalog" / "update-apply-fixture.json").read_text(encoding="utf-8"))
            self.assertEqual(new_head, catalog["revision"])

    def test_unregister_removes_catalog_but_preserves_repository(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory)
            config_dir, reference_root, source = fixture / "config", fixture / "references", fixture / "source"
            source.mkdir()
            (source / "README.md").write_text("fixture\n", encoding="utf-8")
            subprocess.run(["git", "init", "-q"], cwd=source, check=True)
            subprocess.run(["git", "config", "user.email", "awz-test@example.com"], cwd=source, check=True)
            subprocess.run(["git", "config", "user.name", "AWZ Test"], cwd=source, check=True)
            subprocess.run(["git", "add", "README.md"], cwd=source, check=True)
            subprocess.run(["git", "commit", "-qm", "fixture"], cwd=source, check=True)
            preview = self.run_cli(config_dir, "add", "--id", "unregister-fixture", "--url", str(source), "--allow-local", "--dry-run", "--json", reference_root=reference_root)
            added = self.run_cli(config_dir, "add", "--id", "unregister-fixture", "--url", str(source), "--allow-local", "--json", "--plan-hash", json.loads(preview.stdout)["plan"]["planHash"], reference_root=reference_root)
            self.assertEqual(0, added.returncode, added.stderr)
            project = fixture / "project"
            (project / ".awz").mkdir(parents=True)
            mapping_file = project / ".awz" / "references.json"
            mapping_file.write_text('{"schemaVersion":2,"references":[{"id":"unregister-fixture","required":true}]}\n', encoding="utf-8")
            config_dir.mkdir(parents=True, exist_ok=True)
            (config_dir / "config.json").write_text(json.dumps({
                "schemaVersion": 2,
                "referenceRoot": str(reference_root),
                "defaultCloneDepth": 1,
                "networkPolicy": "explicit",
                "executionPolicy": "source-only",
                "knownProjects": [str(project)],
                "trashRetentionDays": 30,
                "logRetentionDays": 90,
            }), encoding="utf-8")
            blocked = self.run_cli(config_dir, "unregister", "--id", "unregister-fixture", "--dry-run", "--json", reference_root=reference_root)
            self.assertEqual(1, blocked.returncode)
            self.assertTrue(json.loads(blocked.stdout)["blockedBy"])
            mapping_file.write_text('{"schemaVersion":2,"references":[]}\n', encoding="utf-8")
            unregister_preview = self.run_cli(config_dir, "unregister", "--id", "unregister-fixture", "--dry-run", "--json", reference_root=reference_root)
            self.assertEqual(0, unregister_preview.returncode, unregister_preview.stderr)
            applied = self.run_cli(config_dir, "unregister", "--id", "unregister-fixture", "--json", "--plan-hash", json.loads(unregister_preview.stdout)["plan"]["planHash"], reference_root=reference_root)
            self.assertEqual(0, applied.returncode, applied.stderr)
            self.assertFalse((reference_root / "catalog" / "unregister-fixture.json").exists())
            self.assertTrue((reference_root / "repos" / "general" / "unregister-fixture" / ".git").exists())

    def test_trash_moves_repo_and_catalog_with_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory)
            config_dir, reference_root, source = fixture / "config", fixture / "references", fixture / "source"
            source.mkdir()
            (source / "README.md").write_text("fixture\n", encoding="utf-8")
            subprocess.run(["git", "init", "-q"], cwd=source, check=True)
            subprocess.run(["git", "config", "user.email", "awz-test@example.com"], cwd=source, check=True)
            subprocess.run(["git", "config", "user.name", "AWZ Test"], cwd=source, check=True)
            subprocess.run(["git", "add", "README.md"], cwd=source, check=True)
            subprocess.run(["git", "commit", "-qm", "fixture"], cwd=source, check=True)
            preview = self.run_cli(config_dir, "add", "--id", "trash-fixture", "--url", str(source), "--allow-local", "--dry-run", "--json", reference_root=reference_root)
            added = self.run_cli(config_dir, "add", "--id", "trash-fixture", "--url", str(source), "--allow-local", "--json", "--plan-hash", json.loads(preview.stdout)["plan"]["planHash"], reference_root=reference_root)
            self.assertEqual(0, added.returncode, added.stderr)
            trash_preview = self.run_cli(config_dir, "trash", "--id", "trash-fixture", "--dry-run", "--json", reference_root=reference_root)
            self.assertEqual(0, trash_preview.returncode, trash_preview.stderr)
            trash_data = json.loads(trash_preview.stdout)["data"]
            self.assertFalse(any((reference_root / "trash").iterdir()))
            applied = self.run_cli(config_dir, "trash", "--id", "trash-fixture", "--json", "--plan-hash", json.loads(trash_preview.stdout)["plan"]["planHash"], reference_root=reference_root)
            self.assertEqual(0, applied.returncode, applied.stderr)
            trash_dir = Path(trash_data["trash"])
            self.assertFalse((reference_root / "catalog" / "trash-fixture.json").exists())
            self.assertFalse((reference_root / "repos" / "general" / "trash-fixture").exists())
            manifest = json.loads((trash_dir / "manifest.json").read_text(encoding="utf-8"))
            self.assertEqual("trashed", manifest["state"])
            self.assertTrue((trash_dir / "repo" / ".git").exists())
            self.assertTrue((trash_dir / "catalog.json").exists())


if __name__ == "__main__":
    unittest.main()
