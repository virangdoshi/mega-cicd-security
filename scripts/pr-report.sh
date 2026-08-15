#!/usr/bin/env bash
# Build a sticky PR comment body and emit GitHub Actions workflow annotations
# from aggregate-results findings-deduped.json (+ optional summary.md).
#
# Usage:
#   pr-report.sh <findings-deduped.json> <out-comment.md> [mode] [run-url] [summary.md]
# mode: comment | annotations | both
set -euo pipefail

FINDINGS_JSON="${1:?findings-deduped.json required}"
OUT_COMMENT="${2:?out comment path required}"
MODE="${3:-both}"
RUN_URL="${4:-}"
SUMMARY_MD="${5:-}"

MARKER='<!-- scankit-pr-report -->'
MAX_ERROR=10
MAX_WARNING=10
MAX_NOTICE=10
MAX_TABLE=25

python3 - "$FINDINGS_JSON" "$OUT_COMMENT" "$MODE" "$RUN_URL" "$SUMMARY_MD" "$MARKER" \
  "$MAX_ERROR" "$MAX_WARNING" "$MAX_NOTICE" "$MAX_TABLE" <<'PY'
import json, os, pathlib, sys, re

findings_path, out_comment, mode, run_url, summary_md, marker = sys.argv[1:7]
max_error, max_warning, max_notice, max_table = map(int, sys.argv[7:11])

data = {"total_raw": 0, "total_unique": 0, "by_severity": {}, "by_tool": {}, "findings": []}
p = pathlib.Path(findings_path)
if p.is_file():
    try:
        data = json.loads(p.read_text(errors="ignore"))
    except Exception:
        pass

findings = list(data.get("findings") or [])
by_sev = data.get("by_severity") or {}
by_tool = data.get("by_tool") or {}
total_unique = int(data.get("total_unique") or len(findings))
total_raw = int(data.get("total_raw") or 0)

def esc(s: str) -> str:
    return (s or "").replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")

def parse_loc(loc: str):
    if not loc:
        return "", ""
    # uri:line — uri may contain colons (windows); split on last :digits
    m = re.match(r"^(.*?):(\d+)$", loc)
    if not m:
        return loc, ""
    path, line = m.group(1), m.group(2)
    # normalize file:/// and leading ./
    path = re.sub(r"^file://", "", path)
    path = path.lstrip("./")
    return path, line

want_comment = mode in ("comment", "both")
want_ann = mode in ("annotations", "both")

# --- workflow command annotations (limit per level per step) ---
if want_ann:
    counts = {"error": 0, "warning": 0, "notice": 0}
    for f in findings:
        sev = (f.get("severity") or "UNKNOWN").upper()
        if sev == "HIGH":
            level, cap = "error", max_error
        elif sev == "MEDIUM":
            level, cap = "warning", max_warning
        else:
            level, cap = "notice", max_notice
        if counts[level] >= cap:
            continue
        path, line = parse_loc(f.get("location") or "")
        if not path or not line:
            continue
        tools = ",".join(f.get("tools") or []) or "scankit"
        rule = f.get("ruleId") or "unknown"
        msg = (f.get("message") or rule).replace("\n", " ")[:180]
        title = f"[{tools}] {rule}"
        # https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions
        print(f"::{level} file={path},line={line},title={esc(title)}::{esc(msg)}")
        counts[level] += 1
    omitted = total_unique - sum(counts.values())
    if omitted > 0:
        print(f"::notice::scankit: {omitted} additional unique findings omitted from annotations (cap {max_error}+{max_warning}+{max_notice})")

# --- sticky PR comment markdown ---
lines = [
    marker,
    "## scankit security report",
    "",
]
if run_url:
    lines.append(f"[Workflow run]({run_url})")
    lines.append("")

lines.append(f"- Unique SARIF findings: **{total_unique}** (raw results: {total_raw})")
for sev in ("HIGH", "MEDIUM", "LOW", "UNKNOWN"):
    if sev in by_sev:
        lines.append(f"- {sev}: **{by_sev[sev]}**")
lines.append("")

if by_tool:
    lines.append("| Tool | Results |")
    lines.append("|------|---------|")
    for tool, n in sorted(by_tool.items(), key=lambda x: (-x[1], x[0]))[:20]:
        lines.append(f"| `{tool}` | {n} |")
    lines.append("")

if findings:
    lines.append("<details>")
    lines.append(f"<summary>Top unique findings (up to {max_table})</summary>")
    lines.append("")
    lines.append("| Sev | Rule | Location | Tools |")
    lines.append("|-----|------|----------|-------|")
    for f in findings[:max_table]:
        loc = (f.get("location") or "").replace("|", "\\|")
        tools = ", ".join(f.get("tools") or [])
        rule = (f.get("ruleId") or "").replace("|", "\\|")
        lines.append(f"| {f.get('severity', '?')} | `{rule}` | `{loc}` | {tools} |")
    lines.append("")
    lines.append("</details>")
    lines.append("")

lines.append("_Secret-scanner raw artifacts are excluded. Prefer Code Scanning for full alert triage._")
lines.append("")
lines.append(f"<!-- mode={mode} unique={total_unique} -->")

pathlib.Path(out_comment).write_text("\n".join(lines) + "\n")

# Job summary (when running in Actions)
step_summary = os.environ.get("GITHUB_STEP_SUMMARY")
if step_summary and want_comment:
    with open(step_summary, "a", encoding="utf-8") as fh:
        # strip HTML marker for step summary readability
        body = "\n".join(lines[1:])
        fh.write(body)
        fh.write("\n")
        if summary_md and pathlib.Path(summary_md).is_file():
            fh.write("\n---\n\n<details><summary>Full aggregate summary</summary>\n\n")
            fh.write(pathlib.Path(summary_md).read_text(errors="ignore")[:50000])
            fh.write("\n</details>\n")

print(f"Wrote PR comment body to {out_comment} ({total_unique} unique findings)")
PY
