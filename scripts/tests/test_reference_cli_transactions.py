from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT_ROOT = Path(__file__).resolve().parents[1]
CLI = SCRIPT_ROOT / "reference-library.py"


class ReferenceCliTransactionTests(unittest.TestCase):
    def run_cli(self, config_dir: Path, *arguments: str) -> subprocess.CompletedProcess[str]:
        environment = os.environ.copy()
        environment["AWZ_CONFIG_DIR"] = str(config_dir)
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


if __name__ == "__main__":
    unittest.main()
