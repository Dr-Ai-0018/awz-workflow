#!/usr/bin/env python3
"""Create a byte-stable gzip stream without depending on zlib compression output."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import struct
import zlib


GZIP_HEADER = b"\x1f\x8b\x08\x00\x00\x00\x00\x00\x00\xff"
BLOCK_SIZE = 65_535


def compress_stored(source: Path, destination: Path) -> None:
    if source.resolve() == destination.resolve():
        raise ValueError("Source and destination must be different files.")

    crc = 0
    size = 0
    created = False
    try:
        with source.open("rb") as reader, destination.open("xb") as writer:
            created = True
            writer.write(GZIP_HEADER)
            current = reader.read(BLOCK_SIZE)
            if not current:
                writer.write(b"\x01\x00\x00\xff\xff")
            else:
                while current:
                    following = reader.read(BLOCK_SIZE)
                    final = not following
                    length = len(current)
                    writer.write(b"\x01" if final else b"\x00")
                    writer.write(struct.pack("<HH", length, length ^ 0xFFFF))
                    writer.write(current)
                    crc = zlib.crc32(current, crc)
                    size = (size + length) & 0xFFFFFFFF
                    current = following
            writer.write(struct.pack("<II", crc & 0xFFFFFFFF, size))
    except BaseException:
        if created:
            destination.unlink(missing_ok=True)
        raise


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    compress_stored(args.source, args.destination)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
