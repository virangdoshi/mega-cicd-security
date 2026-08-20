#!/usr/bin/env bash
# Build inline PR review comment payloads from findings-deduped.json.
# Usage: pr-review-comments.sh <findings-deduped.json> <out-json> [max-comments]
set -euo pipefail

FINDINGS="${1:?findings-deduped.json required}"
OUT="${2:?output json required}"
MAX="${3:-25}"

python3 - "$FINDINGS" "$OUT" "$MAX" <<'PY'
import json, pathlib, re, sys

findings_path, out_path, max_comments = sys.argv[1], sys.argv[2], int(sys.argv[3])
marker = "<!-- scankit-inline -->"

data = {"findings": []}
p = pathlib.Path(findings_path)
if p.is_file():
    try:
        data = json.loads(p.read_text(errors="ignore"))
    except Exception:
        pass

findings = list(data.get("findings") or [])

def normalize_sev(sev: str) -> str:
    s = (sev or "UNKNOWN").upper()
    return "HIGH" if s == "CRITICAL" else s

def parse_loc(loc: str):
    if not loc:
        return "", ""
    m = re.match(r"^(.*):(\d+)$", loc)
    if not m:
        return loc, ""
    path, line = m.group(1), m.group(2)
    if path.startswith("file://"):
        path = path[len("file://") :]
    if path.startswith("./"):
        path = path[2:]
    return path, line

comments = []
seen = set()
for f in findings:
    path, line = parse_loc(f.get("location") or "")
    if not path or not line:
        continue
    try:
        line_n = int(line)
    except ValueError:
        continue
    if line_n < 1:
        continue
    rule = f.get("ruleId") or "unknown"
    sev = normalize_sev(f.get("severity") or "UNKNOWN")
    tools = ", ".join(f.get("tools") or []) or "scankit"
    msg = (f.get("message") or rule).strip().replace("\r", " ")
    key = (path, line_n, rule, msg[:80])
    if key in seen:
        continue
    seen.add(key)
    body = (
        f"{marker}\n"
        f"**{sev}** `{rule}` · _{tools}_\n\n"
        f"{msg[:500]}"
    )
    comments.append(
        {
            "path": path,
            "line": line_n,
            "side": "RIGHT",
            "body": body,
        }
    )
    if len(comments) >= max_comments:
        break

pathlib.Path(out_path).write_text(json.dumps({"comments": comments, "total": len(comments)}, indent=2))
print(f"Wrote {len(comments)} inline review comment(s) to {out_path}")
PY
