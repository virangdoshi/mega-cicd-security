#!/usr/bin/env bash
# Test runner for mega-cicd-security scripts.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PASS=0
FAIL=0

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS  $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $name (expected=$expected actual=$actual)"
    FAIL=$((FAIL + 1))
  fi
}

assert_file() {
  local name="$1" path="$2"
  if [[ -f "$path" ]]; then
    echo "  PASS  $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $name (missing $path)"
    FAIL=$((FAIL + 1))
  fi
}

json_get() {
  local file="$1" key="$2"
  python3 - "$file" "$key" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
key = sys.argv[2]
val = data.get(key)
if isinstance(val, bool):
    print("true" if val else "false")
else:
    print(val)
PY
}

echo "== detect-ecosystems =="

run_detect() {
  local fixture="$1"
  local out
  out="$(mktemp)"
  # Avoid polluting GITHUB_OUTPUT
  env -u GITHUB_OUTPUT "$ROOT/scripts/detect-ecosystems.sh" "$fixture" "$out" >/dev/null
  echo "$out"
}

OUT=$(run_detect tests/fixtures/python-app)
assert_eq "python has_python" "true" "$(json_get "$OUT" has_python)"
assert_eq "python has_go" "false" "$(json_get "$OUT" has_go)"
assert_eq "python has_generic_code" "true" "$(json_get "$OUT" has_generic_code)"
rm -f "$OUT"

OUT=$(run_detect tests/fixtures/go-app)
assert_eq "go has_go" "true" "$(json_get "$OUT" has_go)"
assert_eq "go has_python" "false" "$(json_get "$OUT" has_python)"
rm -f "$OUT"

OUT=$(run_detect tests/fixtures/node-app)
assert_eq "node has_node" "true" "$(json_get "$OUT" has_node)"
rm -f "$OUT"

OUT=$(run_detect tests/fixtures/docker-app)
assert_eq "docker has_docker" "true" "$(json_get "$OUT" has_docker)"
rm -f "$OUT"

OUT=$(run_detect tests/fixtures/openapi-app)
assert_eq "openapi has_openapi" "true" "$(json_get "$OUT" has_openapi)"
rm -f "$OUT"

OUT=$(run_detect tests/fixtures/shell-app)
assert_eq "shell has_shell" "true" "$(json_get "$OUT" has_shell)"
rm -f "$OUT"

OUT=$(run_detect tests/fixtures/mixed-empty)
assert_eq "empty has_python" "false" "$(json_get "$OUT" has_python)"
assert_eq "empty has_generic_code" "true" "$(json_get "$OUT" has_generic_code)"
rm -f "$OUT"

OUT=$(run_detect .)
assert_eq "repo has_actions" "true" "$(json_get "$OUT" has_actions)"
assert_eq "repo has_shell" "true" "$(json_get "$OUT" has_shell)"
rm -f "$OUT"

echo
echo "== aggregate-results =="

ART="$(mktemp -d)"
DEST_ROOT="$(mktemp -d)"
echo '{"has_python":true}' >"$ART/ecosystems.json"
# Two SARIF files with the same finding from different tools (dedup test)
python3 - "$ART" <<'PY'
import json, pathlib, sys
art = pathlib.Path(sys.argv[1])
def sarif(tool, rule="TEST001"):
    return {
      "version": "2.1.0",
      "runs": [{
        "tool": {"driver": {"name": tool, "rules": [{"id": rule, "defaultConfiguration": {"level": "error"}}]}},
        "results": [{
          "ruleId": rule,
          "level": "error",
          "message": {"text": "demo finding"},
          "locations": [{"physicalLocation": {"artifactLocation": {"uri": "src/app.py"}, "region": {"startLine": 10}}}],
        }],
      }],
    }
(art / "tool-a.sarif").write_text(json.dumps(sarif("Trivy")))
(art / "tool-b.sarif").write_text(json.dumps(sarif("Grype")))
(art / "notes.txt").write_text("findings")
p = art / "huge.sarif"
p.write_bytes(b"x" * (6 * 1024 * 1024))
(art / "main.cvd").write_text("db")
PY

"$ROOT/scripts/aggregate-results.sh" "$ART" "$DEST_ROOT" "2099-01-01" >/dev/null

assert_file "summary exists" "$DEST_ROOT/2099-01-01/summary.md"
assert_file "latest summary" "$DEST_ROOT/latest/summary.md"
assert_file "ecosystems copied" "$DEST_ROOT/2099-01-01/ecosystems.json"
assert_file "sarif copied" "$DEST_ROOT/2099-01-01/tool-a.sarif"

if [[ -f "$DEST_ROOT/2099-01-01/main.cvd" ]]; then
  echo "  FAIL  clamav db should not be copied"
  FAIL=$((FAIL + 1))
else
  echo "  PASS  clamav db skipped"
  PASS=$((PASS + 1))
fi

if grep -q 'too large' "$DEST_ROOT/2099-01-01/summary.md"; then
  echo "  PASS  large file noted in summary"
  PASS=$((PASS + 1))
else
  echo "  FAIL  large file not noted"
  FAIL=$((FAIL + 1))
fi

if grep -q '2099-01-01' "$DEST_ROOT/latest/summary.md"; then
  echo "  PASS  latest mirrors dated summary"
  PASS=$((PASS + 1))
else
  echo "  FAIL  latest summary mismatch"
  FAIL=$((FAIL + 1))
fi

assert_file "dedup json exists" "$DEST_ROOT/2099-01-01/findings-deduped.json"
if grep -q 'Findings rollup' "$DEST_ROOT/2099-01-01/summary.md"; then
  echo "  PASS  dedup section in summary"
  PASS=$((PASS + 1))
else
  echo "  FAIL  dedup section missing"
  FAIL=$((FAIL + 1))
fi

DEDUP_STATUS=$(python3 - "$DEST_ROOT/2099-01-01/findings-deduped.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
multi = [f for f in d["findings"] if len(f["tools"]) > 1]
print("dedup_ok" if d["total_unique"] >= 1 and d["total_raw"] >= 2 and multi else "dedup_fail")
PY
)
assert_eq "dedup merges tools" "dedup_ok" "$DEDUP_STATUS"

rm -rf "$ART" "$DEST_ROOT"

echo
echo "== action pins =="
if "$ROOT/scripts/check-action-pins.sh"; then
  echo "  PASS  action pins"
  PASS=$((PASS + 1))
else
  echo "  FAIL  action pins"
  FAIL=$((FAIL + 1))
fi

echo
echo "== actionlint =="

ACTIONLINT_BIN="$(mktemp -d)/actionlint"
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64) ARCH=amd64 ;;
  arm64|aarch64) ARCH=arm64 ;;
esac
# Download latest actionlint release binary
AL_URL=$(curl -fsSL https://api.github.com/repos/rhysd/actionlint/releases/latest \
  | python3 -c "import sys,json,re; assets=json.load(sys.stdin).get('assets',[]);
pat=re.compile(r'actionlint_.*_${OS}_${ARCH}\\.tar\\.gz$');
print(next((a['browser_download_url'] for a in assets if pat.search(a['name'])), ''))")
if [[ -n "$AL_URL" ]]; then
  curl -fsSL "$AL_URL" | tar -xz -C "$(dirname "$ACTIONLINT_BIN")" actionlint
  chmod +x "$ACTIONLINT_BIN"
  set +e
  "$ACTIONLINT_BIN" -color -shellcheck= -pyflakes= .github/workflows/*.yml
  AL_EXIT=$?
  set -e
  if [[ "$AL_EXIT" -eq 0 ]]; then
    echo "  PASS  actionlint clean"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  actionlint reported issues (exit $AL_EXIT)"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  FAIL  could not download actionlint"
  FAIL=$((FAIL + 1))
fi

echo
echo "== workflow / template presence =="

for f in \
  .github/workflows/reusable-security-full.yml \
  .github/workflows/reusable-sca.yml \
  .github/workflows/reusable-sast.yml \
  .github/workflows/reusable-secrets.yml \
  .github/workflows/reusable-container.yml \
  .github/workflows/reusable-iac.yml \
  .github/workflows/reusable-sbom.yml \
  .github/workflows/reusable-supply-chain.yml \
  .github/workflows/reusable-privacy.yml \
  .github/workflows/reusable-api.yml \
  .github/workflows/reusable-malware.yml \
  .github/workflows/reusable-meta.yml \
  .github/workflows/reusable-publish-results.yml \
  .github/workflows/ci-self-test.yml \
  templates/security-all.yml \
  templates/security-all-scheduled.yml \
  docs/scanners.md \
  README.md
do
  assert_file "exists $f" "$ROOT/$f"
done

# Basic YAML front matter / workflow_call sanity
if grep -q 'workflow_call' .github/workflows/reusable-security-full.yml; then
  echo "  PASS  full suite is reusable"
  PASS=$((PASS + 1))
else
  echo "  FAIL  full suite missing workflow_call"
  FAIL=$((FAIL + 1))
fi

if grep -q 'results-publish-mode' templates/security-all-scheduled.yml; then
  echo "  PASS  scheduled template publishes results"
  PASS=$((PASS + 1))
else
  echo "  FAIL  scheduled template missing publish mode"
  FAIL=$((FAIL + 1))
fi

echo
echo "Results: $PASS passed, $FAIL failed"
if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi
echo "All tests passed."
