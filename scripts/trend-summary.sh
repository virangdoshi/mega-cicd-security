#!/usr/bin/env bash
# Compare findings-deduped.json across dated security-results folders.
# Usage: trend-summary.sh [security-results-root]
set -euo pipefail
ROOT="${1:-security-results}"
python3 - "$ROOT" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
dates = sorted([p for p in root.iterdir() if p.is_dir() and p.name != "latest"], key=lambda p: p.name)
if not dates:
    print("No dated result folders under", root)
    sys.exit(0)
print("# Security trend summary\n")
print("| Date | Unique | HIGH | MEDIUM | LOW |")
print("|------|--------|------|--------|-----|")
prev = None
for d in dates[-14:]:
    f = d / "findings-deduped.json"
    if not f.is_file():
        continue
    data = json.loads(f.read_text())
    by = data.get("by_severity") or {}
    u = data.get("total_unique", 0)
    row = (d.name, u, by.get("HIGH", 0), by.get("MEDIUM", 0), by.get("LOW", 0))
    delta = ""
    if prev:
        delta = f" ({u - prev:+d})"
    print(f"| {row[0]} | {row[1]}{delta} | {row[2]} | {row[3]} | {row[4]} |")
    prev = u
PY
