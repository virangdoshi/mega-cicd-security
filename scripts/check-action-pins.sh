#!/usr/bin/env bash
# Fail if any third-party GitHub Action is not pinned to a 40-char commit SHA.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail=0
while IFS= read -r -d '' file; do
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Trim leading spaces for matching
    trimmed="${line#"${line%%[![:space:]]*}"}"
    case "$trimmed" in
      uses:*) ;;
      *) continue ;;
    esac
    # Local reusable workflows / composite actions
    if [[ "$trimmed" == uses:+./ ]]; then
      continue
    fi
    if [[ "$trimmed" == uses:./ ]]; then
      continue
    fi
    if echo "$trimmed" | grep -q 'uses: \./'; then
      continue
    fi
    if ! echo "$trimmed" | grep -q '@'; then
      echo "UNPINNED ($file): $trimmed"
      fail=1
      continue
    fi
    ref="${trimmed#*@}"
    ref="${ref%%[[:space:]]*}"
    ref="${ref%%#*}"
    if echo "$ref" | grep -Eq '^[0-9a-f]{40}$'; then
      continue
    fi
    echo "UNPINNED ($file): $trimmed"
    fail=1
  done < "$file"
done < <(find .github templates -type f \( -name '*.yml' -o -name '*.yaml' \) -print0)

if [[ "$fail" -ne 0 ]]; then
  echo
  echo "All third-party / remote actions must use a full 40-char commit SHA (optional # vX.Y.Z comment)."
  echo "Local uses (./.github/...) are allowed. Dependabot refreshes SHAs weekly."
  exit 1
fi

echo "All remote Action refs are SHA-pinned."
