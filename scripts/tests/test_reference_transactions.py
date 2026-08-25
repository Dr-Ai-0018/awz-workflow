from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT_ROOT = Path(__file__).resolve().parents[1]
if str(SCRIPT_ROOT) not in sys.path:
    sys.path.insert(0, str(SCRIPT_ROOT))

from reference_library.contracts import build_plan  # noqa: E402
from reference_library.errors import ReferenceLibraryError  # noqa: E402
from reference_library.transactions import (  # noqa: E402
    ReferenceTransaction,
    redact_sensitive,
)


class ReferenceTransactionTests(unittest.TestCase):
    def make_plan(self) -> dict:
        return build_plan(
            "reference.test",
            [
                {"kind": "ensure-layout", "target": "library", "summary": "prepare layout"},
                {"kind": "write-json", "target": "catalog/test.json", "summary": "write catalog"},
            ],
            [],
            validated_inputs={"id": "test"},
        )

    def read_record(self, transaction: ReferenceTransaction) -> dict:
        return json.loads(transaction.path.read_text(encoding="utf-8"))

    def test_transaction_records_each_state_and_action(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            transaction = ReferenceTransaction(Path(directory), "reference.test", self.make_plan())
            planned = self.read_record(transaction)
            self.assertEqual("planned", planned["state"])
            self.assertEqual(0, len(planned["completed"]))
            self.assertEqual(2, len(planned["remaining"]))

            transaction.begin_apply()
            transaction.complete_action(0)
            applying = self.read_record(transaction)
            self.assertEqual("applying", applying["state"])
            self.assertEqual(1, len(applying["completed"]))
            self.assertEqual(1, len(applying["remaining"]))

            transaction.complete()
            completed = self.read_record(transaction)
            self.assertEqual("completed", completed["state"])
            self.assertEqual(2, len(completed["completed"]))
            self.assertEqual([], completed["remaining"])
            self.assertEqual([], completed["recovery"])
            self.assertIsNone(completed["error"])

    def test_failed_transaction_redacts_secrets_and_urls(self) -> None:
        plan = build_plan(
            "reference.test",
            [
                {
                    "kind": "probe",
                    "target": "https://user:password@example.com/repo.git?token=value#fragment",
                    "apiToken": "must-not-appear",
                }
            ],
            [],
        )
        with tempfile.TemporaryDirectory() as directory:
            transaction = ReferenceTransaction(Path(directory), "reference.test", plan)
            transaction.begin_apply()
            transaction.fail(
                RuntimeError("failed for https://user:secret@example.com/repo.git?token=value"),
                ["Retry https://user:secret@example.com/repo.git?token=value after review."],
            )
            record_text = transaction.path.read_text(encoding="utf-8")
            record = json.loads(record_text)

            self.assertEqual("failed", record["state"])
            self.assertIn("https://example.com/repo.git", record["error"])
            self.assertNotIn("user:secret", record_text)
            self.assertNotIn("must-not-appear", record_text)
            self.assertNotIn("token=value", record_text)
            self.assertEqual("[redacted]", record["actions"][0]["apiToken"])
            self.assertEqual(0, len(record["completed"]))
            self.assertEqual(1, len(record["remaining"]))

    def test_redaction_preserves_non_sensitive_values(self) -> None:
        redacted = redact_sensitive(
            {
                "path": "E:/Project/AWZ References",
                "repositoryUrl": "https://example.com/repo.git",
                "password": "private",
            }
        )
        self.assertEqual("E:/Project/AWZ References", redacted["path"])
        self.assertEqual("https://example.com/repo.git", redacted["repositoryUrl"])
        self.assertEqual("[redacted]", redacted["password"])

    def test_domain_error_carries_recovery_context(self) -> None:
        error = ReferenceLibraryError(
            "operation failed",
            recovery=["inspect the transaction"],
            transaction={"transactionId": "test", "state": "failed"},
        )
        self.assertEqual(["inspect the transaction"], error.recovery)
        self.assertEqual("failed", error.transaction["state"])

    def test_invalid_state_transition_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            transaction = ReferenceTransaction(Path(directory), "reference.test", self.make_plan())
            with self.assertRaisesRegex(ValueError, "only complete from the applying state"):
                transaction.complete()
            with self.assertRaisesRegex(ValueError, "only complete while applying"):
                transaction.complete_action(0)


if __name__ == "__main__":
    unittest.main()
