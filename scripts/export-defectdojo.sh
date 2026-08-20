#!/usr/bin/env bash
# Bundle SARIF artifacts for DefectDojo import (upload via UI or API).
# Usage: export-defectdojo.sh <artifacts-dir> <out-zip>
set -euo pipefail
ART="${1:?artifacts dir}"
OUT="${2:?output zip}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
find "$ART" -type f \( -name '*.sarif' -o -name '*.sarif.json' \) -exec cp {} "$TMP/" \;
if [[ -z "$(ls -A "$TMP" 2>/dev/null)" ]]; then
  echo "No SARIF files found in $ART" >&2
  exit 1
fi
(
  cd "$TMP"
  zip -q -r "$OUT" .
)
echo "Wrote DefectDojo bundle: $OUT ($(find "$TMP" -type f | wc -l | tr -d ' ') files)"
