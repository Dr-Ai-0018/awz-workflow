import gzip
from pathlib import Path
import tempfile
import unittest

from scripts.lib.deterministic_gzip import GZIP_HEADER, compress_stored


class DeterministicGzipTests(unittest.TestCase):
    def test_round_trip_and_stable_bytes(self):
        content = (b"AWZ\x00\xff" * 20_000) + b"tail"
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source.tar"
            first = root / "first.tar.gz"
            second = root / "second.tar.gz"
            source.write_bytes(content)

            compress_stored(source, first)
            compress_stored(source, second)

            self.assertEqual(first.read_bytes(), second.read_bytes())
            self.assertEqual(first.read_bytes()[:10], GZIP_HEADER)
            self.assertEqual(gzip.decompress(first.read_bytes()), content)

    def test_empty_input_round_trip(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "empty.tar"
            destination = root / "empty.tar.gz"
            source.write_bytes(b"")

            compress_stored(source, destination)

            self.assertEqual(gzip.decompress(destination.read_bytes()), b"")


if __name__ == "__main__":
    unittest.main()
