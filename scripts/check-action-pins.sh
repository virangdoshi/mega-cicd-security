#!/usr/bin/env bash
# Fail if any third-party GitHub Action is not pinned to a 40-char commit SHA.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail=0
while IFS= read -r -d '' file; do
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Trim leading spaces
    trimmed="${line#"${line%%[![:space:]]*}"}"
    # Support both `uses:` and list form `- uses:`
    case "$trimmed" in
      uses:*)
        rest="${trimmed#uses:}"
        ;;
      -[[:space:]]uses:*)
        rest="${trimmed#-}"
        rest="${rest#"${rest%%[![:space:]]*}"}"
        rest="${rest#uses:}"
        ;;
      *)
        continue
        ;;
    esac
    rest="${rest#"${rest%%[![:space:]]*}"}"

    # Local reusable workflows / composite actions
    if [[ "$rest" == ./* ]] || [[ "$rest" == .github/* ]]; then
      continue
    fi

    if [[ "$rest" != *@* ]]; then
      echo "UNPINNED ($file): $trimmed"
      fail=1
      continue
    fi

    ref="${rest#*@}"
    ref="${ref%%[[:space:]]*}"
    ref="${ref%%#*}"
    if [[ "$ref" =~ ^[0-9a-f]{40}$ ]]; then
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
