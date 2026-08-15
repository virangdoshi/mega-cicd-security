#!/usr/bin/env bash
# Test runner for scankit scripts.
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
(art / "detect-secrets.json").write_text('{"results":[]}')
(art / "secretlint.json").write_text('[]')
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

if [[ -f "$DEST_ROOT/2099-01-01/detect-secrets.json" ]] || [[ -f "$DEST_ROOT/2099-01-01/secretlint.json" ]]; then
  echo "  FAIL  secret-scanner artifacts should not be copied"
  FAIL=$((FAIL + 1))
else
  echo "  PASS  secret-scanner artifacts skipped"
  PASS=$((PASS + 1))
fi

if grep -q 'secret-scanner artifact' "$DEST_ROOT/2099-01-01/summary.md"; then
  echo "  PASS  secret skip noted in summary"
  PASS=$((PASS + 1))
else
  echo "  FAIL  secret skip not noted"
  FAIL=$((FAIL + 1))
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

echo
echo "== pr-report =="
PR_TMP="$(mktemp -d)"
# Reuse a minimal findings file
cat >"$PR_TMP/findings.json" <<'JSON'
{
  "total_raw": 2,
  "total_unique": 2,
  "by_severity": {"HIGH": 1, "MEDIUM": 1},
  "by_tool": {"Semgrep": 1, "Bandit": 1},
  "findings": [
    {"key": "a", "ruleId": "python.lang.security.audit", "severity": "HIGH", "location": "python/app.py:3", "message": "use of assert", "tools": ["Semgrep"], "sources": ["sast-semgrep"]},
    {"key": "b", "ruleId": "B201", "severity": "MEDIUM", "location": "python/app.py:10", "message": "flask debug true", "tools": ["Bandit"], "sources": ["sast-bandit"]}
  ]
}
JSON
PR_OUT="$("$ROOT/scripts/pr-report.sh" "$PR_TMP/findings.json" "$PR_TMP/comment.md" both "https://example.test/run/1" 2>&1)"
assert_file "pr comment exists" "$PR_TMP/comment.md"
if grep -q 'scankit-pr-report' "$PR_TMP/comment.md" && grep -q 'Unique SARIF findings' "$PR_TMP/comment.md"; then
  echo "  PASS  pr comment marker + summary"
  PASS=$((PASS + 1))
else
  echo "  FAIL  pr comment content"
  FAIL=$((FAIL + 1))
fi
if printf '%s\n' "$PR_OUT" | grep -q '::error file=python/app.py,line=3'; then
  echo "  PASS  pr annotation error"
  PASS=$((PASS + 1))
else
  echo "  FAIL  pr annotation error missing"
  FAIL=$((FAIL + 1))
fi
if printf '%s\n' "$PR_OUT" | grep -q '::warning file=python/app.py,line=10'; then
  echo "  PASS  pr annotation warning"
  PASS=$((PASS + 1))
else
  echo "  FAIL  pr annotation warning missing"
  FAIL=$((FAIL + 1))
fi
rm -rf "$PR_TMP"

rm -rf "$ART" "$DEST_ROOT"

echo
echo "== resolve-scan-scope / filter-changed-files =="

SCOPE_TMP="$(mktemp -d)"
pushd "$SCOPE_TMP" >/dev/null
git init -q
git config user.email "test@example.com"
git config user.name "test"
mkdir -p python .github/workflows docker
echo 'print(1)' > python/app.py
echo 'Django==1' > python/requirements.txt
echo 'FROM scratch' > docker/Dockerfile
echo 'name: x' > .github/workflows/ci.yml
echo '# readme' > README.md
git add -A && git commit -qm base
BASE=$(git rev-parse HEAD)

echo 'print(2)' >> python/app.py
git add -A && git commit -qm py-only
HEAD_PY=$(git rev-parse HEAD)

rm -f /tmp/gh-scope-out
env GITHUB_OUTPUT=/tmp/gh-scope-out "$ROOT/scripts/resolve-scan-scope.sh" auto pull_request "$BASE" "$HEAD_PY" "$SCOPE_TMP/out-py" >/dev/null
assert_eq "py-only scan_scope" "diff" "$(grep '^scan_scope=' /tmp/gh-scope-out | cut -d= -f2)"
assert_eq "py-only scope_sast" "true" "$(grep '^scope_sast=' /tmp/gh-scope-out | cut -d= -f2)"
assert_eq "py-only scope_sca" "false" "$(grep '^scope_sca=' /tmp/gh-scope-out | cut -d= -f2)"
assert_eq "py-only scope_dockerfile" "false" "$(grep '^scope_dockerfile=' /tmp/gh-scope-out | cut -d= -f2)"
FILTERED=$("$ROOT/scripts/filter-changed-files.sh" "$SCOPE_TMP/out-py/changed-files.txt" '\.py$')
assert_eq "filter py" "python/app.py" "$FILTERED"

git checkout -q "$BASE"
echo 'extra' >> README.md
git add -A && git commit -qm readme-only
HEAD_README=$(git rev-parse HEAD)
rm -f /tmp/gh-scope-out
env GITHUB_OUTPUT=/tmp/gh-scope-out "$ROOT/scripts/resolve-scan-scope.sh" auto pull_request "$BASE" "$HEAD_README" "$SCOPE_TMP/out-readme" >/dev/null
assert_eq "readme scope_sast" "false" "$(grep '^scope_sast=' /tmp/gh-scope-out | cut -d= -f2)"
assert_eq "readme scope_secrets" "true" "$(grep '^scope_secrets=' /tmp/gh-scope-out | cut -d= -f2)"
assert_eq "readme scope_sca" "false" "$(grep '^scope_sca=' /tmp/gh-scope-out | cut -d= -f2)"

git checkout -q "$BASE"
echo 'Flask==1' >> python/requirements.txt
git add -A && git commit -qm reqs
HEAD_REQ=$(git rev-parse HEAD)
rm -f /tmp/gh-scope-out
env GITHUB_OUTPUT=/tmp/gh-scope-out "$ROOT/scripts/resolve-scan-scope.sh" auto pull_request "$BASE" "$HEAD_REQ" "$SCOPE_TMP/out-reqs" >/dev/null
assert_eq "reqs scope_python_manifest" "true" "$(grep '^scope_python_manifest=' /tmp/gh-scope-out | cut -d= -f2)"
assert_eq "reqs scope_sca" "true" "$(grep '^scope_sca=' /tmp/gh-scope-out | cut -d= -f2)"

rm -f /tmp/gh-scope-out
env GITHUB_OUTPUT=/tmp/gh-scope-out "$ROOT/scripts/resolve-scan-scope.sh" auto push "" "" "$SCOPE_TMP/out-full" >/dev/null
assert_eq "push auto is full" "full" "$(grep '^scan_scope=' /tmp/gh-scope-out | cut -d= -f2)"
assert_eq "full scope_sast" "true" "$(grep '^scope_sast=' /tmp/gh-scope-out | cut -d= -f2)"

popd >/dev/null
rm -rf "$SCOPE_TMP"

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
# Pinned actionlint release
AL_VERSION=1.7.7
AL_TGZ="$(dirname "$ACTIONLINT_BIN")/actionlint.tgz"
AL_URL="https://github.com/rhysd/actionlint/releases/download/v${AL_VERSION}/actionlint_${AL_VERSION}_${OS}_${ARCH}.tar.gz"
if curl -fsSL "$AL_URL" -o "$AL_TGZ"; then
  if [[ "$OS" == "linux" && "$ARCH" == "amd64" ]]; then
    bash scripts/verify-sha256.sh "$AL_TGZ" 023070a287cd8cccd71515fedc843f1985bf96c436b7effaecce67290e7e0757
  fi
  tar -xzf "$AL_TGZ" -C "$(dirname "$ACTIONLINT_BIN")" actionlint
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
  .github/workflows/reusable-pr-report.yml \
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

if grep -q 'scan-scope' .github/workflows/reusable-security-full.yml; then
  echo "  PASS  full suite has scan-scope"
  PASS=$((PASS + 1))
else
  echo "  FAIL  full suite missing scan-scope"
  FAIL=$((FAIL + 1))
fi

if grep -q 'scan-scope: full' templates/security-all-scheduled.yml; then
  echo "  PASS  scheduled template forces full scan-scope"
  PASS=$((PASS + 1))
else
  echo "  FAIL  scheduled template missing scan-scope: full"
  FAIL=$((FAIL + 1))
fi

if grep -q 'pr-report-mode' .github/workflows/reusable-security-full.yml; then
  echo "  PASS  full suite has pr-report-mode"
  PASS=$((PASS + 1))
else
  echo "  FAIL  full suite missing pr-report-mode"
  FAIL=$((FAIL + 1))
fi

if grep -q 'pr-report-mode' .github/workflows/reusable-pr-report.yml; then
  echo "  PASS  pr-report workflow present"
  PASS=$((PASS + 1))
else
  echo "  FAIL  pr-report workflow missing"
  FAIL=$((FAIL + 1))
fi

echo
echo "Results: $PASS passed, $FAIL failed"
if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi
echo "All tests passed."
