#!/usr/bin/env python3
"""Safe manifest-based refresh entry point for AWZ-managed project files."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Any, Dict, Optional

from project_refresh.core import apply_refresh, scan_refresh
from reference_library.contracts import operation_result, print_result
from reference_library.errors import ReferenceLibraryError


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Safely refresh AWZ-managed project files.")
    parser.add_argument("--target", required=True, help="Initialized project directory.")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--dry-run", action="store_true", help="Preview classifications and changes without writing.")
    mode.add_argument("--apply", action="store_true", help="Apply a previously previewed plan.")
    parser.add_argument("--plan-hash", help="Required with --apply; must match the current DryRun planHash.")
    parser.add_argument("--json", dest="json_output", action="store_true", help="Emit the machine-readable result contract.")
    parser.add_argument("--workflow-root", help=argparse.SUPPRESS)
    return parser


def result_data(scan: Dict[str, Any], transaction: Any = None) -> Dict[str, Any]:
    data = {
        "target": str(scan["target"]),
        "manifestPath": str(scan["manifestPath"]),
        "files": scan["files"],
    }
    if transaction is not None:
        data["transaction"] = transaction.summary()
    return data


def print_text_preview(scan: Dict[str, Any]) -> None:
    print(f"Refresh target: {scan['target']}")
    for item in scan["files"]:
        classification = item["classification"]
        if classification != "unchanged":
            diff = item["diff"]
            print(
                f"{classification.upper()}: {item['path']} "
                f"(+{diff['addedLines']}/-{diff['removedLines']})"
            )
    for blocker in scan["plan"]["blockedBy"]:
        print(f"BLOCKED: {blocker}")
    print(f"Plan hash: {scan['plan']['planHash']}")
    print("DryRun: no files were written.")


def main(argv: Optional[list[str]] = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    workflow_root = Path(args.workflow_root).resolve(strict=True) if args.workflow_root else Path(__file__).resolve().parents[1]
    try:
        scan = scan_refresh(workflow_root, Path(args.target))
        if args.dry_run:
            exit_code = 2 if scan["plan"]["blockedBy"] else 0
            if args.json_output:
                print_result(
                    operation_result(
                        "project.refresh",
                        exit_code,
                        dry_run=True,
                        plan=scan["plan"],
                        data=result_data(scan),
                    )
                )
            else:
                print_text_preview(scan)
            return exit_code

        if not args.plan_hash:
            raise ReferenceLibraryError("--apply requires --plan-hash from the prior DryRun preview.")
        transaction = apply_refresh(scan, args.plan_hash)
        if args.json_output:
            print_result(
                operation_result(
                    "project.refresh",
                    0,
                    dry_run=False,
                    plan=scan["plan"],
                    data=result_data(scan, transaction),
                )
            )
        elif transaction is None:
            print("Refresh complete: no changes were required.")
        else:
            print(f"Refresh complete: {scan['target']}")
            print(f"Transaction: {transaction.path}")
        return 0
    except ReferenceLibraryError as error:
        if args.json_output:
            data = {"transaction": error.transaction} if error.transaction else {}
            print_result(
                operation_result(
                    "project.refresh",
                    1,
                    dry_run=bool(args.dry_run),
                    data=data,
                    blocked_by=[str(error)],
                    recovery=error.recovery,
                )
            )
        else:
            print(f"Error: {error}", file=sys.stderr)
            if error.transaction:
                print(f"Transaction: {error.transaction.get('path', '<unknown>')}", file=sys.stderr)
            for step in error.recovery:
                print(f"Recovery: {step}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
