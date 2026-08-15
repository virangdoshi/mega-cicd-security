#!/usr/bin/env bash
# Filter a changed-files list by extended regex patterns.
#
# Usage:
#   filter-changed-files.sh <changed-files.txt> <regex> [regex...]
#
# Prints matching paths (one per line) to stdout.
# Exit 0 even when no matches (empty output).
set -euo pipefail

LIST="${1:?changed-files.txt required}"
shift

if [[ ! -f "$LIST" ]]; then
  echo "Missing changed-files list: $LIST" >&2
  exit 1
fi

if [[ ! -s "$LIST" ]]; then
  exit 0
fi

if [[ "$#" -eq 0 ]]; then
  cat "$LIST"
  exit 0
fi

# Combine patterns with |
combined=""
for re in "$@"; do
  if [[ -z "$combined" ]]; then
    combined="$re"
  else
    combined="$combined|$re"
  fi
done

grep -E "$combined" "$LIST" || true
