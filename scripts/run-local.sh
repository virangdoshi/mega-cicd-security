#!/usr/bin/env bash
# Run a minimal local scan subset (no GitHub Actions required).
# Usage: run-local.sh [--profile minimal|standard] [--path DIR]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="minimal"
TARGET="${ROOT}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --path) TARGET="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: run-local.sh [--profile minimal|standard] [--path DIR]"
      exit 0 ;;
    *) echo "Unknown: $1" >&2; exit 1 ;;
  esac
done

ECO="$(mktemp)"
SCOPE="$(mktemp)"
"$ROOT/scripts/detect-ecosystems.sh" "$TARGET" "$ECO"
echo "== Ecosystems =="
cat "$ECO"
echo

PROF_OUT="$(mktemp)"
"$ROOT/scripts/resolve-profile.sh" "$PROFILE" "$PROF_OUT"
echo "== Profile: $PROFILE =="
cat "$PROF_OUT"
echo

run_if() { grep -q "^$1=true" "$PROF_OUT" || grep -q "^$1=true$" "$PROF_OUT"; }

echo "== Local scanners (best-effort) =="
if command -v actionlint >/dev/null 2>&1 && grep -q has_actions.*true "$ECO" 2>/dev/null || python3 -c "import json; print(json.load(open('$ECO')).get('has_actions'))" | grep -q True; then
  echo "--- actionlint ---"
  actionlint "$TARGET/.github/workflows/"*.yml 2>/dev/null || actionlint "$TARGET" 2>/dev/null || true
fi
if command -v semgrep >/dev/null 2>&1; then
  echo "--- semgrep (auto) ---"
  semgrep scan --config auto --error "$TARGET" 2>/dev/null || true
fi
if command -v gitleaks >/dev/null 2>&1; then
  echo "--- gitleaks ---"
  gitleaks detect --source "$TARGET" --no-git -v 2>/dev/null || true
fi
if command -v pip-audit >/dev/null 2>&1 && python3 -c "import json; print(json.load(open('$ECO')).get('has_python'))" | grep -q True; then
  echo "--- pip-audit ---"
  pip-audit -r "$TARGET/requirements.txt" 2>/dev/null || pip-audit "$TARGET" 2>/dev/null || true
fi

echo
echo "Local scan complete. Install semgrep, gitleaks, actionlint, pip-audit for broader coverage."
echo "CodeQL and container scans require CI or dedicated CLI setup."

rm -f "$ECO" "$SCOPE" "$PROF_OUT"
