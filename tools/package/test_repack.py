#!/usr/bin/env python3
"""CPU-only regression checks for device ZIP recompression."""
from pathlib import Path
import tempfile
import unittest
import warnings
import zipfile
import zlib
from repack import repack


class RepackTests(unittest.TestCase):
    def test_lossless_stored_images_and_deterministic(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "channel.zip"
            data = {"manifest": b"title=Reef Tank\n" * 1000,
                    "source/main.brs": bytes(range(256)) * 30,
                    "images/fish.png": bytes(range(256)) * 10,
                    "config/": b""}
            with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=1) as archive:
                for name, content in data.items():
                    method = zipfile.ZIP_STORED if name.startswith("images/") or name.endswith("/") else zipfile.ZIP_DEFLATED
                    archive.writestr(name, content, compress_type=method)
            old, new = repack(path)
            self.assertLess(new, old)
            with zipfile.ZipFile(path) as archive:
                self.assertEqual(archive.namelist(), sorted(data))
                self.assertEqual(archive.getinfo("images/fish.png").compress_type, zipfile.ZIP_STORED)
                self.assertIsNone(archive.testzip())
                compressor = zlib.compressobj(level=6, wbits=-15)
                expected = compressor.compress(data["manifest"]) + compressor.flush()
                self.assertEqual(archive.getinfo("manifest").compress_size, len(expected))
                for name, content in data.items():
                    self.assertEqual(archive.read(name), content)
            first = path.read_bytes()
            repack(path)
            self.assertEqual(path.read_bytes(), first)

    def test_input_order_and_timestamps_do_not_change_output(self):
        with tempfile.TemporaryDirectory() as directory:
            paths = [Path(directory) / "a.zip", Path(directory) / "b.zip"]
            for i, path in enumerate(paths):
                with zipfile.ZipFile(path, "w") as archive:
                    names = ["manifest", "source/main.brs"]
                    if i:
                        names.reverse()
                    for name in names:
                        info = zipfile.ZipInfo(name, (2020 + i, 1, 1, 0, 0, 0))
                        info.compress_type = zipfile.ZIP_DEFLATED
                        archive.writestr(info, name.encode())
                repack(path)
            self.assertEqual(paths[0].read_bytes(), paths[1].read_bytes())

    def test_reject_duplicate_without_replacing_original(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "channel.zip"
            with warnings.catch_warnings():
                warnings.simplefilter("ignore", UserWarning)
                with zipfile.ZipFile(path, "w") as archive:
                    archive.writestr("manifest", b"one")
                    archive.writestr("manifest", b"two")
            original = path.read_bytes()
            with self.assertRaisesRegex(ValueError, "duplicate"):
                repack(path)
            self.assertEqual(path.read_bytes(), original)
            self.assertEqual(list(Path(directory).iterdir()), [path])

    def test_reject_compressed_image(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "channel.zip"
            with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
                archive.writestr("images/fish.png", b"image bytes")
            original = path.read_bytes()
            with self.assertRaisesRegex(ValueError, "STORE"):
                repack(path)
            self.assertEqual(path.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
