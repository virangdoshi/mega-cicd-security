#!/usr/bin/env bash
# Load .scankit.yml / .scankit.yaml (simple key: value subset) into GITHUB_OUTPUT.
# Usage: load-scankit-config.sh <config-path> [out-file]
set -euo pipefail

CONFIG="${1:-.scankit.yml}"
OUT="${2:-}"

if [[ ! -f "$CONFIG" ]]; then
  exit 0
fi

python3 - "$CONFIG" "$OUT" <<'PY'
import pathlib, re, sys

config_path = pathlib.Path(sys.argv[1])
out_path = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else ""

lines = config_path.read_text(encoding="utf-8", errors="ignore").splitlines()
data = {}
for raw in lines:
    line = raw.split("#", 1)[0].strip()
    if not line or line.startswith("---"):
        continue
    m = re.match(r"^([A-Za-z0-9_-]+):\s*(.+?)\s*$", line)
    if not m:
        continue
    key, val = m.group(1), m.group(2).strip()
    if (val.startswith('"') and val.endswith('"')) or (val.startswith("'") and val.endswith("'")):
        val = val[1:-1]
    data[key.replace("_", "-")] = val

out_lines = []
for k, v in sorted(data.items()):
    safe_k = k.replace(" ", "-")
    out_lines.append(f"{safe_k}={v}")

text = "\n".join(out_lines) + ("\n" if out_lines else "")
if out_path:
    pathlib.Path(out_path).write_text(text, encoding="utf-8")
else:
    sys.stdout.write(text)
PY
