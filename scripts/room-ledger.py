#!/usr/bin/env python3
"""Run the canonical room ledger shipped in the project template."""

from pathlib import Path
import runpy


if __name__ == "__main__":
    template = Path(__file__).resolve().parents[1] / "templates" / "project" / "room-ledger.py"
    runpy.run_path(str(template), run_name="__main__")
