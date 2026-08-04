#!/usr/bin/env python3
"""Cross-platform smoke test for the room ledger CLI and concurrency boundary."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ENTRY = ROOT / "scripts" / "room-ledger.py"


def run(ledger: Path, *arguments: str, check: bool = True) -> subprocess.CompletedProcess:
    command = [sys.executable, str(ENTRY), *arguments, "--ledger", str(ledger)]
    result = subprocess.run(command, capture_output=True, text=True)
    if check and result.returncode != 0:
        raise AssertionError(
            "command failed:\n"
            + " ".join(command)
            + f"\nstdout={result.stdout}\nstderr={result.stderr}"
        )
    return result


def main() -> int:
    temp_root = ROOT / "temp"
    temp_root.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="smoke-room-ledger-", dir=str(temp_root)) as directory:
        ledger = Path(directory) / "room.ndjson"
        run(ledger, "append", "--writer", "codex", "--kind", "note", "--body", "initial note")
        assert (
            run(
                ledger,
                "append",
                "--writer",
                "codex",
                "--kind",
                "amend",
                "--ref",
                "room_missing",
                "--body",
                "must reference an existing record",
                check=False,
            ).returncode
            != 0
        )

        workers = []
        for index in range(8):
            command = [
                sys.executable,
                str(ENTRY),
                "append",
                "--ledger",
                str(ledger),
                "--writer",
                f"worker-{index}",
                "--kind",
                "note",
                "--body",
                f"concurrent note {index}",
            ]
            workers.append(subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True))
        results = [worker.communicate() for worker in workers]
        for worker, result in zip(workers, results):
            if worker.returncode != 0:
                raise AssertionError(f"concurrent append failed: {result}")

        records = [json.loads(line) for line in ledger.read_text(encoding="utf-8").splitlines()]
        first_id = records[0]["id"]
        run(
            ledger,
            "append",
            "--writer",
            "codex",
            "--kind",
            "amend",
            "--ref",
            first_id,
            "--body",
            "clarifies the initial note",
        )
        run(ledger, "verify")

        records = [json.loads(line) for line in ledger.read_text(encoding="utf-8").splitlines()]
        assert [record["seq"] for record in records] == list(range(1, 11))
        assert len({record["id"] for record in records}) == 10

        tampered = ledger.read_text(encoding="utf-8").replace("initial note", "tampered note", 1)
        with ledger.open("w", encoding="utf-8", newline="") as stream:
            stream.write(tampered)
        assert run(ledger, "verify", check=False).returncode != 0
        assert (
            run(
                ledger,
                "append",
                "--writer",
                "codex",
                "--kind",
                "note",
                "--body",
                "must be rejected after tampering",
                check=False,
            ).returncode
            != 0
        )

    print("Room ledger smoke passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
