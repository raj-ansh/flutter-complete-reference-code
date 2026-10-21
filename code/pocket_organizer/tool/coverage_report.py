"""Summarizes coverage/lcov.info (written by `flutter test --coverage`).

Usage: python tool/coverage_report.py [lcov file]

Prints lines hit / lines found per file, grouped by folder, and a total.
"""
import sys
from collections import defaultdict

path = sys.argv[1] if len(sys.argv) > 1 else "coverage/lcov.info"
files = {}
current = None
found = hit = 0
for raw in open(path, encoding="utf-8"):
    line = raw.strip()
    if line.startswith("SF:"):
        current = line[3:].replace("\\", "/")
        found = hit = 0
    elif line.startswith("LF:"):
        found = int(line[3:])
    elif line.startswith("LH:"):
        hit = int(line[3:])
    elif line == "end_of_record" and current:
        files[current] = (hit, found)
        current = None

groups = defaultdict(lambda: [0, 0])
for name, (h, f) in files.items():
    folder = name.rsplit("/", 1)[0] if "/" in name else "."
    groups[folder][0] += h
    groups[folder][1] += f

print(f"{'file':52}{'hit':>6}{'lines':>7}{'  %':>7}")
for name in sorted(files):
    h, f = files[name]
    pct = 100 * h / f if f else 100
    print(f"{name:52}{h:>6}{f:>7}{pct:>6.0f}%")
total_h = sum(h for h, _ in files.values())
total_f = sum(f for _, f in files.values())
print("-" * 72)
print(f"{'TOTAL':52}{total_h:>6}{total_f:>7}{100 * total_h / total_f:>6.1f}%")
