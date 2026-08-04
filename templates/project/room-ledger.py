#!/usr/bin/env python3
"""Append-only, tamper-evident room ledger with no third-party dependencies."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import sys
import time
import uuid
from pathlib import Path
from typing import Any, Dict, List, Optional, Sequence


SCHEMA_VERSION = 1
GENESIS_HASH = "0" * 64
LABEL_PATTERN = re.compile(r"^[^\s\r\n/\\|]{1,64}$")
REFERENCE_PATTERN = re.compile(r"^[^\s\r\n]{1,160}$")
TIMESTAMP_PATTERN = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$")
ID_PATTERN = re.compile(r"^room_(\d{8}T\d{9}Z)_(\d{6})_([0-9a-f]{12})$")
HASH_PATTERN = re.compile(r"^[0-9a-f]{64}$")
RECORD_FIELDS = frozenset(
    {
        "schema",
        "seq",
        "id",
        "created_at",
        "writer",
        "kind",
        "refs",
        "body",
        "prev_hash",
        "hash",
    }
)


class LedgerError(RuntimeError):
    """Raised when the ledger is invalid or an append cannot be trusted."""


def canonical_json(value: Dict[str, Any]) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def record_hash(record: Dict[str, Any]) -> str:
    payload = {key: record[key] for key in RECORD_FIELDS if key != "hash"}
    material = record["prev_hash"] + "\n" + canonical_json(payload)
    return hashlib.sha256(material.encode("utf-8")).hexdigest()


def validate_label(value: str, field_name: str) -> None:
    if not isinstance(value, str) or not LABEL_PATTERN.fullmatch(value):
        raise LedgerError(
            f"{field_name} must be 1-64 characters without whitespace, slash, backslash, or '|'."
        )


def validate_reference(value: str) -> None:
    if not isinstance(value, str) or not REFERENCE_PATTERN.fullmatch(value):
        raise LedgerError("references must be non-empty values without whitespace.")


def validate_record(record: Dict[str, Any], expected_seq: int, previous_hash: str) -> None:
    if set(record) != RECORD_FIELDS:
        raise LedgerError(f"record {expected_seq} has an unexpected field set.")
    if (
        isinstance(record["schema"], bool)
        or not isinstance(record["schema"], int)
        or record["schema"] != SCHEMA_VERSION
    ):
        raise LedgerError(f"record {expected_seq} uses an unsupported schema.")
    if (
        isinstance(record["seq"], bool)
        or not isinstance(record["seq"], int)
        or record["seq"] != expected_seq
    ):
        raise LedgerError(f"record {expected_seq} has a broken sequence number.")
    id_match = ID_PATTERN.fullmatch(record["id"]) if isinstance(record["id"], str) else None
    if id_match is None:
        raise LedgerError(f"record {expected_seq} has an invalid id.")
    if not isinstance(record["created_at"], str) or not TIMESTAMP_PATTERN.fullmatch(
        record["created_at"]
    ):
        raise LedgerError(f"record {expected_seq} has an invalid UTC timestamp.")
    try:
        dt.datetime.strptime(record["created_at"], "%Y-%m-%dT%H:%M:%S.%fZ")
    except ValueError as exc:
        raise LedgerError(f"record {expected_seq} has an impossible UTC timestamp.") from exc
    timestamp_key = record["created_at"].replace("-", "").replace(":", "").replace(".", "")
    if id_match.group(1) != timestamp_key or id_match.group(2) != f"{expected_seq:06d}":
        raise LedgerError(f"record {expected_seq} has an id/timestamp/sequence mismatch.")
    validate_label(record["writer"], "writer")
    validate_label(record["kind"], "kind")
    if not isinstance(record["refs"], list) or not all(
        isinstance(reference, str) for reference in record["refs"]
    ):
        raise LedgerError(f"record {expected_seq} has invalid references.")
    for reference in record["refs"]:
        validate_reference(reference)
    if not isinstance(record["body"], str) or not record["body"].strip():
        raise LedgerError(f"record {expected_seq} has an empty body.")
    if record["prev_hash"] != previous_hash or not HASH_PATTERN.fullmatch(record["prev_hash"]):
        raise LedgerError(f"record {expected_seq} has a broken previous-hash link.")
    if not isinstance(record["hash"], str) or not HASH_PATTERN.fullmatch(record["hash"]):
        raise LedgerError(f"record {expected_seq} has an invalid hash.")
    if record_hash(record) != record["hash"]:
        raise LedgerError(f"record {expected_seq} failed hash verification.")


def read_records(ledger: Path) -> List[Dict[str, Any]]:
    if not ledger.exists():
        return []
    if not ledger.is_file():
        raise LedgerError(f"ledger path is not a file: {ledger}")

    raw = ledger.read_bytes()
    if not raw:
        return []
    if raw.startswith(b"\xef\xbb\xbf"):
        raise LedgerError("ledger must be UTF-8 without a BOM.")
    if b"\r" in raw:
        raise LedgerError("ledger must use LF line endings; do not rewrite it with a text editor.")
    if not raw.endswith(b"\n"):
        raise LedgerError("ledger does not end with a complete line.")

    records: List[Dict[str, Any]] = []
    previous_hash = GENESIS_HASH
    seen_ids = set()
    lines = raw.split(b"\n")[:-1]
    for expected_seq, line in enumerate(lines, start=1):
        if not line:
            raise LedgerError(f"ledger contains an empty line at position {expected_seq}.")
        try:
            record = json.loads(line.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise LedgerError(f"ledger line {expected_seq} is not valid UTF-8 JSON.") from exc
        if not isinstance(record, dict):
            raise LedgerError(f"ledger line {expected_seq} is not a JSON object.")
        validate_record(record, expected_seq, previous_hash)
        if record["id"] in seen_ids:
            raise LedgerError(f"record id is duplicated: {record['id']}")
        seen_ids.add(record["id"])
        records.append(record)
        previous_hash = record["hash"]
    return records


class LedgerLock:
    """A small cross-platform advisory lock shared by every ledger writer."""

    def __init__(self, lock_path: Path, timeout_seconds: float = 30.0) -> None:
        self.lock_path = lock_path
        self.timeout_seconds = timeout_seconds
        self.handle = None

    def __enter__(self) -> "LedgerLock":
        self.lock_path.parent.mkdir(parents=True, exist_ok=True)
        self.handle = self.lock_path.open("a+b")
        try:
            if os.name == "nt":
                import msvcrt

                self.handle.seek(0, os.SEEK_END)
                if self.handle.tell() == 0:
                    self.handle.write(b"0")
                    self.handle.flush()
                self.handle.seek(0)
                deadline = time.monotonic() + self.timeout_seconds
                while True:
                    try:
                        msvcrt.locking(self.handle.fileno(), msvcrt.LK_NBLCK, 1)
                        break
                    except OSError:
                        if time.monotonic() >= deadline:
                            raise LedgerError(f"timed out waiting for ledger lock: {self.lock_path}")
                        time.sleep(0.05)
            else:
                import fcntl

                fcntl.flock(self.handle.fileno(), fcntl.LOCK_EX)
            return self
        except Exception:
            self.handle.close()
            self.handle = None
            raise

    def __exit__(self, _exc_type: Any, _exc_value: Any, _traceback: Any) -> None:
        if self.handle is None:
            return
        if os.name == "nt":
            import msvcrt

            self.handle.seek(0)
            msvcrt.locking(self.handle.fileno(), msvcrt.LK_UNLCK, 1)
        else:
            import fcntl

            fcntl.flock(self.handle.fileno(), fcntl.LOCK_UN)
        self.handle.close()
        self.handle = None


def utc_timestamp() -> str:
    now = dt.datetime.now(dt.timezone.utc)
    return now.strftime("%Y-%m-%dT%H:%M:%S.") + f"{now.microsecond // 1000:03d}Z"


def append_record(ledger: Path, writer: str, kind: str, refs: Sequence[str], body: str) -> Dict[str, Any]:
    validate_label(writer, "writer")
    validate_label(kind, "kind")
    if kind == "amend" and not refs:
        raise LedgerError("amend records must reference the record they correct with --ref.")
    for reference in refs:
        validate_reference(reference)
    if not body.strip():
        raise LedgerError("body must not be empty.")

    ledger.parent.mkdir(parents=True, exist_ok=True)
    lock_path = Path(str(ledger) + ".lock")
    with LedgerLock(lock_path):
        records = read_records(ledger)
        if kind == "amend":
            existing_ids = {record["id"] for record in records}
            missing_refs = [reference for reference in refs if reference not in existing_ids]
            if missing_refs:
                raise LedgerError(
                    "amend references unknown record id(s): " + ", ".join(missing_refs)
                )
        seq = len(records) + 1
        created_at = utc_timestamp()
        timestamp_key = created_at.replace("-", "").replace(":", "").replace(".", "")
        record: Dict[str, Any] = {
            "schema": SCHEMA_VERSION,
            "seq": seq,
            "id": f"room_{timestamp_key}_{seq:06d}_{uuid.uuid4().hex[:12]}",
            "created_at": created_at,
            "writer": writer,
            "kind": kind,
            "refs": list(refs),
            "body": body,
            "prev_hash": records[-1]["hash"] if records else GENESIS_HASH,
        }
        record["hash"] = record_hash(record)
        line = (canonical_json(record) + "\n").encode("utf-8")
        with ledger.open("ab") as stream:
            stream.write(line)
            stream.flush()
            os.fsync(stream.fileno())

        verified_records = read_records(ledger)
        raw = ledger.read_bytes()
        if (
            not verified_records
            or verified_records[-1]["id"] != record["id"]
            or not raw.endswith(line)
            or raw.count(line) != 1
        ):
            raise LedgerError("post-append verification failed; ledger was not trusted.")
        return record


def read_body(args: argparse.Namespace) -> str:
    if args.body is not None and args.body_file is not None:
        raise LedgerError("use either --body or --body-file, not both.")
    if args.body is not None:
        return args.body
    if args.body_file is None:
        raise LedgerError("append requires --body or --body-file.")
    if args.body_file == "-":
        return sys.stdin.read()
    try:
        return Path(args.body_file).read_text(encoding="utf-8")
    except OSError as exc:
        raise LedgerError(f"cannot read body file: {args.body_file}") from exc


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Append-only, tamper-evident room ledger. Never edit the ledger by hand."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    append_parser = subparsers.add_parser("append", help="append one immutable record")
    append_parser.add_argument("--ledger", type=Path, default=Path("docs/agent-room/room.ndjson"))
    append_parser.add_argument("--writer", required=True, help="agent or human writer label")
    append_parser.add_argument("--kind", required=True, help="chat, handoff, review, decision, note, amend, import")
    append_parser.add_argument("--ref", action="append", default=[], help="record id being referenced; repeatable")
    append_parser.add_argument("--body", help="short body text")
    append_parser.add_argument("--body-file", help="UTF-8 body file, or '-' for stdin")

    verify_parser = subparsers.add_parser("verify", help="verify sequence, hash chain, and file ending")
    verify_parser.add_argument("--ledger", type=Path, default=Path("docs/agent-room/room.ndjson"))

    tail_parser = subparsers.add_parser("tail", help="verify and print the newest records")
    tail_parser.add_argument("--ledger", type=Path, default=Path("docs/agent-room/room.ndjson"))
    tail_parser.add_argument("--count", type=int, default=10)
    return parser


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        if args.command == "append":
            record = append_record(
                args.ledger,
                args.writer,
                args.kind,
                args.ref,
                read_body(args),
            )
            print(f"Appended {record['id']} seq={record['seq']} hash={record['hash']}")
            return 0

        records = read_records(args.ledger)
        if args.command == "verify":
            last = records[-1]["id"] if records else "none"
            print(f"Ledger OK: records={len(records)} last={last}")
            return 0

        if args.count < 1:
            raise LedgerError("--count must be at least 1.")
        for record in records[-args.count :]:
            print(json.dumps(record, ensure_ascii=False, indent=2, sort_keys=True))
        return 0
    except (LedgerError, OSError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
