#!/usr/bin/env python3
"""Lossless device ZIP normalization: DEFLATE 6, unchanged STORE entries.

Only ZIP metadata/compression changes. Payloads are verified before atomic replace.
Stable order/timestamps make repeated builds reproducible on the same zlib version.
"""
import argparse
import os
from pathlib import Path
import tempfile
import zipfile


def repack(path: Path) -> tuple[int, int]:
    before = path.stat().st_size
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    os.close(fd)
    temp = Path(temporary)
    try:
        with zipfile.ZipFile(path) as source:
            entries = source.infolist()
            names = [entry.filename for entry in entries]
            if len(names) != len(set(names)):
                raise ValueError("duplicate ZIP entries are not supported")
            with zipfile.ZipFile(temp, "w", compression=zipfile.ZIP_DEFLATED,
                                 compresslevel=6, allowZip64=False) as target:
                for entry in sorted(entries, key=lambda item: item.filename):
                    if entry.compress_type not in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED):
                        raise ValueError(f"unsupported compression: {entry.filename}")
                    if entry.filename.startswith("images/") and entry.compress_type != zipfile.ZIP_STORED:
                        raise ValueError(f"image must use STORE: {entry.filename}")
                    info = zipfile.ZipInfo(entry.filename, date_time=(1980, 1, 1, 0, 0, 0))
                    info.compress_type = entry.compress_type
                    info.create_system = 3
                    info.external_attr = (0o40755 << 16 | 0x10) if entry.is_dir() else (0o100644 << 16)
                    target.writestr(info, source.read(entry), compresslevel=6)
            with zipfile.ZipFile(temp) as target:
                if set(target.namelist()) != set(names):
                    raise ValueError("repacked member list differs")
                for entry in entries:
                    if target.getinfo(entry.filename).compress_type != entry.compress_type:
                        raise ValueError(f"compression method changed: {entry.filename}")
                    if target.read(entry.filename) != source.read(entry):
                        raise ValueError(f"payload changed: {entry.filename}")
        os.replace(temp, path)
        return before, path.stat().st_size
    finally:
        temp.unlink(missing_ok=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    args = parser.parse_args()
    old, new = repack(args.archive)
    print(f"lossless ZIP DEFLATE-6: {old:,} -> {new:,} bytes ({old-new:,} saved)")
