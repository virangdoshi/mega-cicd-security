#!/usr/bin/env bash
# Aggregate downloaded scanner artifacts into security-results/<date>/ and latest/.
set -euo pipefail

ARTIFACTS_DIR="${1:-artifacts}"
OUT_ROOT="${2:-security-results}"
DATE_STAMP="${3:-$(date -u +%Y-%m-%d)}"

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

# Copy report-like files; skip clamav DB dumps
while IFS= read -r -d '' f; do
  base="$(basename "$f")"
  case "$base" in
    *.cvd|*.cld|*clamav*db*|main.cvd|daily.cvd) continue ;;
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

{
  echo
  echo "## Notes"
  echo
  echo "- SARIF may also be available in GitHub Code Scanning."
  echo "- Large antivirus databases are not committed."
} >>"$summary"

rm -rf "${LATEST:?}/"*
cp -R "${DEST}/." "$LATEST/"

echo "Aggregated results into ${DEST} and ${LATEST}"
