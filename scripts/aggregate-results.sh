#!/usr/bin/env bash
# Aggregate downloaded scanner artifacts into security-results/<date>/ and latest/.
# Also builds a cross-tool SARIF dedup summary (findings-deduped.json + section in summary.md).
set -euo pipefail

ARTIFACTS_DIR="${1:-artifacts}"
OUT_ROOT="${2:-security-results}"
DATE_STAMP="${3:-$(date -u +%Y-%m-%d)}"

# Refuse path traversal via '..' components (absolute paths OK for local/CI temp dirs)
contains_dotdot() {
  local p="$1"
  [[ "$p" == *'/../'* || "$p" == '../'* || "$p" == *'/..' || "$p" == '..' ]]
}
if contains_dotdot "$OUT_ROOT" || [[ -z "$OUT_ROOT" ]]; then
  echo "Refusing unsafe out-root: $OUT_ROOT" >&2
  exit 1
fi
if contains_dotdot "$ARTIFACTS_DIR"; then
  echo "Refusing unsafe artifacts-dir: $ARTIFACTS_DIR" >&2
  exit 1
fi

DEST="${OUT_ROOT}/${DATE_STAMP}"
LATEST="${OUT_ROOT}/latest"
mkdir -p "$DEST" "$LATEST"

MAX_BYTES=$((5 * 1024 * 1024)) # 5 MiB per file copy cap

summary="${DEST}/summary.md"
{
  echo "# Security scan results — ${DATE_STAMP}"
  echo
  echo "Generated (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
  echo "## Ecosystems"
  if [[ -f "${ARTIFACTS_DIR}/ecosystems.json" ]]; then
    cp "${ARTIFACTS_DIR}/ecosystems.json" "${DEST}/ecosystems.json"
    echo '```json'
    cat "${ARTIFACTS_DIR}/ecosystems.json"
    echo '```'
  elif [[ -f ecosystems.json ]]; then
    cp ecosystems.json "${DEST}/ecosystems.json"
    echo '```json'
    cat ecosystems.json
    echo '```'
  else
    echo "_No ecosystems.json found._"
  fi
  echo
  echo "## Artifacts"
  echo
  echo "| File | Size |"
  echo "|------|------|"
} >"$summary"

# Copy report-like files; skip clamav DB dumps and secret-scanner raw output
# (never commit potential live secrets into git via publish).
while IFS= read -r -d '' f; do
  base="$(basename "$f")"
  lower="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')"
  case "$lower" in
    *.cvd|*.cld|*clamav*db*|main.cvd|daily.cvd) continue ;;
    *gitleaks*|*trufflehog*|*detect-secrets*|*secretlint*|*secrets*.json|*secret*.sarif)
      echo "| \`${base}\` | (skipped, secret-scanner artifact) |" >>"$summary"
      continue
      ;;
  esac
  size="$(wc -c <"$f" | tr -d ' ')"
  if (( size > MAX_BYTES )); then
    echo "| \`${base}\` | ${size} (skipped, too large) |" >>"$summary"
    continue
  fi
  rel="$(echo "$f" | sed "s|^${ARTIFACTS_DIR}/||")"
  safe="$(echo "$rel" | tr '/' '_')"
  cp "$f" "${DEST}/${safe}"
  echo "| \`${safe}\` | ${size} |" >>"$summary"
done < <(find "$ARTIFACTS_DIR" -type f \( \
  -name '*.sarif' -o -name '*.sarif.json' -o -name '*.json' -o -name '*.txt' -o -name '*.md' -o -name '*.xml' -o -name '*.spdx*' -o -name '*.cdx.json' -o -name 'cyclonedx*' \
  \) -print0 2>/dev/null)

# Cross-tool SARIF deduplication / severity rollup
python3 - "$ARTIFACTS_DIR" "$DEST" "$summary" <<'PY'
import json, pathlib, sys, hashlib, collections

artifacts = pathlib.Path(sys.argv[1])
dest = pathlib.Path(sys.argv[2])
summary = pathlib.Path(sys.argv[3])

def severity_of(result, tool_rules):
    level = (result.get("level") or "").lower()
    if not level:
        rule_id = result.get("ruleId") or ""
        rule = tool_rules.get(rule_id) or {}
        props = rule.get("properties") or {}
        level = (props.get("security-severity") or props.get("problem.severity") or rule.get("defaultConfiguration", {}).get("level") or "warning")
        if isinstance(level, (int, float)):
            # CVSS-ish
            level = "error" if float(level) >= 7 else "warning" if float(level) >= 4 else "note"
        level = str(level).lower()
    if level in ("error", "critical", "high"):
        return "HIGH"
    if level in ("warning", "medium"):
        return "MEDIUM"
    if level in ("note", "info", "informational", "low"):
        return "LOW"
    return "UNKNOWN"

findings = []
by_key = {}
sev_counts = collections.Counter()
tool_counts = collections.Counter()
cat_counts = collections.Counter()

def categorize(tool: str, rule_id: str) -> str:
    t = (tool or "").lower()
    r = (rule_id or "").lower()
    blob = t + " " + r
    if any(x in blob for x in ("gitleaks", "trufflehog", "detect-secrets", "secretlint", "secret")):
        return "secrets"
    if any(x in blob for x in ("trivy", "grype", "osv", "dependency", "cargo", "pip-audit", "govuln", "retire", "bundler", "php-security")):
        return "sca"
    if any(x in blob for x in ("semgrep", "codeql", "bandit", "gosec", "brakeman", "spotbugs", "devskim", "shellcheck")):
        return "sast"
    if any(x in blob for x in ("checkov", "kics", "terraform", "kube", "terrascan", "conftest", "cfn-guard")):
        return "iac"
    if any(x in blob for x in ("scorecard", "pinact", "ratchet", "guarddog", "sbom", "slsa")):
        return "supply-chain"
    if any(x in blob for x in ("hadolint", "dockle", "dive", "docker")):
        return "container"
    if any(x in blob for x in ("bearer", "presidio", "privacy")):
        return "privacy"
    if any(x in blob for x in ("spectral", "openapi", "graphql", "vacuum")):
        return "api"
    return "other"

for path in artifacts.rglob("*"):
    if not path.is_file():
        continue
    name = path.name.lower()
    if not (name.endswith(".sarif") or name.endswith(".sarif.json")):
        continue
    try:
        data = json.loads(path.read_text(errors="ignore"))
    except Exception:
        continue
    if not isinstance(data, dict) or "runs" not in data:
        continue
    for run in data.get("runs") or []:
        tool = (((run.get("tool") or {}).get("driver") or {}).get("name")) or path.stem
        rules = {}
        for r in ((run.get("tool") or {}).get("driver") or {}).get("rules") or []:
            if isinstance(r, dict) and r.get("id"):
                rules[r["id"]] = r
        for result in run.get("results") or []:
            loc = ""
            locs = result.get("locations") or []
            if locs:
                pl = (locs[0].get("physicalLocation") or {})
                art = (pl.get("artifactLocation") or {}).get("uri") or ""
                region = pl.get("region") or {}
                line = region.get("startLine") or ""
                loc = f"{art}:{line}"
            rule_id = result.get("ruleId") or "unknown"
            msg = ((result.get("message") or {}).get("text") or "")[:200]
            sev = severity_of(result, rules)
            if sev == "CRITICAL":
                sev = "HIGH"
            cat = categorize(tool, rule_id)
            key_src = f"{rule_id}|{loc}|{msg[:80]}"
            key = hashlib.sha1(key_src.encode()).hexdigest()[:16]
            entry = {
                "key": key,
                "ruleId": rule_id,
                "severity": sev,
                "category": cat,
                "location": loc,
                "message": msg,
                "tools": [tool],
                "sources": [str(path.relative_to(artifacts))],
            }
            sev_counts[sev] += 1
            tool_counts[tool] += 1
            cat_counts[cat] += 1
            if key in by_key:
                existing = by_key[key]
                if tool not in existing["tools"]:
                    existing["tools"].append(tool)
                src = str(path.relative_to(artifacts))
                if src not in existing["sources"]:
                    existing["sources"].append(src)
            else:
                by_key[key] = entry
                findings.append(entry)

deduped = {
    "total_raw": int(sum(sev_counts.values())),
    "total_unique": len(findings),
    "by_severity": dict(sev_counts),
    "by_tool": dict(tool_counts),
    "by_category": dict(cat_counts),
    "findings": sorted(findings, key=lambda f: ({"HIGH":0,"MEDIUM":1,"LOW":2,"UNKNOWN":3}.get(f["severity"], 9), f["ruleId"])),
}
(dest / "findings-deduped.json").write_text(json.dumps(deduped, indent=2))

dup_tools = sum(1 for f in findings if len(f["tools"]) > 1)

with summary.open("a") as fh:
    fh.write("\n## Findings rollup (SARIF dedup)\n\n")
    fh.write(f"- Raw SARIF results: **{deduped['total_raw']}**\n")
    fh.write(f"- Unique findings (rule + location + message): **{deduped['total_unique']}**\n")
    fh.write(f"- Reported by multiple tools: **{dup_tools}**\n\n")
    if cat_counts:
        fh.write("| Category | Count |\n|----------|-------|\n")
        for cat, n in sorted(cat_counts.items(), key=lambda x: (-x[1], x[0])):
            fh.write(f"| {cat} | {n} |\n")
        fh.write("\n")
    fh.write("| Severity | Count |\n|----------|-------|\n")
    for sev in ("HIGH", "MEDIUM", "LOW", "UNKNOWN"):
        if sev in sev_counts:
            fh.write(f"| {sev} | {sev_counts[sev]} |\n")
    fh.write("\n| Tool | Results |\n|------|--------|\n")
    for tool, n in sorted(tool_counts.items(), key=lambda x: (-x[1], x[0])):
        fh.write(f"| `{tool}` | {n} |\n")
    if findings:
        fh.write("\n### Top unique findings\n\n")
        fh.write("| Sev | Rule | Location | Tools |\n|-----|------|----------|-------|\n")
        for f in deduped["findings"][:40]:
            loc = (f["location"] or "").replace("|", "\\|")
            tools = ", ".join(f["tools"])
            fh.write(f"| {f['severity']} | `{f['ruleId']}` | `{loc}` | {tools} |\n")
    fh.write("\nSee `findings-deduped.json` for the full unique set.\n")
PY

{
  echo
  echo "## Notes"
  echo
  echo "- SARIF may also be available in GitHub Code Scanning."
  echo "- Large antivirus databases are not committed."
  echo "- Secret-scanner raw JSON/SARIF is excluded from publish."
  echo "- Dedup is best-effort across SARIF only (JSON-only scanners are listed as artifacts)."
} >>"$summary"

rm -rf "${LATEST:?}/"*
cp -R "${DEST}/." "$LATEST/"

echo "Aggregated results into ${DEST} and ${LATEST}"
