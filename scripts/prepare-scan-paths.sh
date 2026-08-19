#!/usr/bin/env bash
# Filter changed-files for a scanner. Used by .github/actions/prepare-scan-paths.
#
# Env:
#   SCAN_SCOPE          diff | full (required)
#   PATTERNS            space-separated extended regexes (optional)
#   CHANGED_FILES_PATH  path to changed-files.txt (default: changed-files.txt)
#   PATHS_FILE          output path list (default: scan-paths.txt)
#   GITHUB_OUTPUT       required (Actions output file)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN_SCOPE="${SCAN_SCOPE:?SCAN_SCOPE required}"
PATTERNS="${PATTERNS:-}"
CHANGED_FILES_PATH="${CHANGED_FILES_PATH:-changed-files.txt}"
PATHS_FILE="${PATHS_FILE:-scan-paths.txt}"
out="${GITHUB_OUTPUT:?GITHUB_OUTPUT required}"

: >"$PATHS_FILE"

if [[ "$SCAN_SCOPE" != "diff" ]]; then
  echo "skip=false" >>"$out"
  echo "path_args=." >>"$out"
  echo "path_count=0" >>"$out"
  echo "paths_file=$PATHS_FILE" >>"$out"
  echo "." >"$PATHS_FILE"
  exit 0
fi

SRC="$CHANGED_FILES_PATH"
if [[ ! -f "$SRC" ]]; then
  if [[ -f changed-files/changed-files.txt ]]; then
    SRC=changed-files/changed-files.txt
  elif [[ -f changed-files.txt ]]; then
    SRC=changed-files.txt
  else
    echo "No changed-files list found; skip"
    echo "skip=true" >>"$out"
    echo "path_args=" >>"$out"
    echo "path_count=0" >>"$out"
    echo "paths_file=$PATHS_FILE" >>"$out"
    exit 0
  fi
fi

if [[ -n "${PATTERNS// }" ]]; then
  # shellcheck disable=SC2086
  bash "${REPO_ROOT}/scripts/filter-changed-files.sh" "$SRC" $PATTERNS >"$PATHS_FILE"
else
  cp "$SRC" "$PATHS_FILE"
fi

TMP=$(mktemp)
while IFS= read -r p; do
  [[ -z "$p" ]] && continue
  [[ -e "$p" || -L "$p" ]] && printf '%s\n' "$p"
done <"$PATHS_FILE" >"$TMP"
mv "$TMP" "$PATHS_FILE"

COUNT=$(grep -c . "$PATHS_FILE" || true)
if [[ "$COUNT" -eq 0 ]]; then
  echo "skip=true" >>"$out"
  echo "path_args=" >>"$out"
  echo "path_count=0" >>"$out"
  echo "paths_file=$PATHS_FILE" >>"$out"
  exit 0
fi

ARGS=""
while IFS= read -r p; do
  [[ -z "$p" ]] && continue
  ARGS+=" $(printf '%q' "$p")"
done <"$PATHS_FILE"
echo "skip=false" >>"$out"
echo "path_args=${ARGS# }" >>"$out"
echo "path_count=$COUNT" >>"$out"
echo "paths_file=$PATHS_FILE" >>"$out"
echo "Prepared $COUNT path(s) for scan"
