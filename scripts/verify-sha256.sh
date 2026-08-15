#!/usr/bin/env bash
# Usage: verify-sha256.sh <file> <expected-sha256>
set -euo pipefail
file="$1"
want="$2"
got="$(shasum -a 256 "$file" | awk '{print $1}')"
if [[ "$got" != "$want" ]]; then
  echo "SHA256 mismatch for $file" >&2
  echo "  expected: $want" >&2
  echo "  got:      $got" >&2
  exit 1
fi
