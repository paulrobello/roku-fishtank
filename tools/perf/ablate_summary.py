#!/usr/bin/env python3
"""Median fps per cut from a run_channel.sh console log (PERF ... cut=<id> lines).
Usage: ablate_summary.py <console.log>. The first 3 s after each cut change are skipped."""
import re
import statistics
import sys

segments: dict[str, list[int]] = {}
prev = None
skip = 0
for line in open(sys.argv[1]):
    m = re.search(r"PERF t= *(\d+) fps= *(\d+) mode=(\w+) blend= *([\d.e-]+)\s+cut=(\S+)", line)
    if not m:
        continue
    cut = m.group(5)
    if cut != prev:
        prev, skip = cut, 3
    if skip > 0:
        skip -= 1
        continue
    segments.setdefault(cut, []).append(int(m.group(2)))
for cut, v in segments.items():
    print(f"{cut:16} n={len(v):3} min={min(v):2} median={statistics.median(v):5.1f} max={max(v):2}")
