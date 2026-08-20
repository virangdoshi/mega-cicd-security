#!/usr/bin/env bash
# Replace template/README pin SHAs with the given commit (default: HEAD).
set -euo pipefail
SHA="${1:-$(git rev-parse HEAD)}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
while IFS= read -r f; do
  sed -i '' -E "s/@[0-9a-f]{40}/@${SHA}/g" "$f"
  echo "Updated $f"
done < <(rg -l '@[0-9a-f]{40}' templates docs README.md examples 2>/dev/null || true)
echo "Pinned templates to $SHA"
