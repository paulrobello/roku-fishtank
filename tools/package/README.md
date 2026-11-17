# Lossless device ZIP compression

All supported device package paths (Makefile build, probe-build, check-build,
fidelity-build, and tools/perf/run_channel.sh) run `repack.py` after BSC creates
its ZIP. CI inherits this through `make zip-check fidelity-build` and runs the
regression tests through `make test`. The browser preview's temporary in-memory
ZIP is not a device artifact and is unchanged.

The Python standard-library implementation uses DEFLATE level 6 for entries
already using DEFLATE and preserves STORE for images and directory entries.
No dependencies are patched, no file content is minified, and no image is
re-encoded. The script rejects duplicate members, unsupported compression, and
compressed images. Before atomic replacement, it verifies identical member names,
compression methods, and every decompressed byte. Failed validation leaves the
original package untouched.

Entry order, timestamps, permissions and ZIP metadata are normalized; payloads
are not. Output is reproducible for a fixed Python/zlib toolchain, not promised
byte-identical across different zlib versions. Repacking signed/encrypted Roku
packages is unsupported: this operates only on unsigned BSC output before upload.

Run `python3 tools/package/test_repack.py` for CPU-only checks of losslessness,
STORE images, level-6 compressed length, deterministic output, idempotence, and
safe failure. Existing store size/API/content guards still run independently.
