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

# Batch several key assertions from one ecosystems.json (one python startup).
assert_flags() {
  local name_prefix="$1" file="$2"
  shift 2
  local result
  result="$(python3 - "$file" "$@" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
args = sys.argv[2:]
# pairs: key expected
out = []
for i in range(0, len(args), 2):
    key, expected = args[i], args[i + 1]
    val = data.get(key)
    actual = "true" if val is True else "false" if val is False else str(val)
    out.append(f"{key}\t{expected}\t{actual}")
print("\n".join(out))
PY
)"
  while IFS=$'\t' read -r key expected actual; do
    [[ -z "$key" ]] && continue
    assert_eq "${name_prefix} ${key}" "$expected" "$actual"
  done <<<"$result"
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
assert_flags "python" "$OUT" has_python true has_go false has_generic_code true
rm -f "$OUT"

OUT=$(run_detect tests/fixtures/go-app)
assert_flags "go" "$OUT" has_go true has_python false
rm -f "$OUT"

OUT=$(run_detect tests/fixtures/node-app)
assert_flags "node" "$OUT" has_node true
rm -f "$OUT"

OUT=$(run_detect tests/fixtures/docker-app)
assert_flags "docker" "$OUT" has_docker true
rm -f "$OUT"

OUT=$(run_detect tests/fixtures/openapi-app)
assert_flags "openapi" "$OUT" has_openapi true
rm -f "$OUT"

OUT=$(run_detect tests/fixtures/shell-app)
assert_flags "shell" "$OUT" has_shell true
rm -f "$OUT"

OUT=$(run_detect tests/fixtures/mixed-empty)
assert_flags "empty" "$OUT" has_python false has_generic_code true
rm -f "$OUT"

OUT=$(run_detect tests/fixtures/actions-app)
assert_flags "actions" "$OUT" has_actions true has_shell true
rm -f "$OUT"

echo
echo "== aggregate-results =="

ART="$(mktemp -d)"
DEST_ROOT="$(mktemp -d)"
echo '{"has_python":true}' >"$ART/ecosystems.json"
# Two SARIF files with the same finding from different tools (dedup test)
python3 - "$ART" <<'PY'
import json, pathlib, sys, os
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
# Sparse >5 MiB file (avoid writing 6 MiB of zeros each run)
p = art / "huge.sarif"
p.touch()
os.truncate(p, 6 * 1024 * 1024)
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
# ./prefix and multi-tool title must not break workflow-command properties
cat >"$PR_TMP/findings2.json" <<'JSON'
{
  "total_raw": 1, "total_unique": 1, "by_severity": {"HIGH": 1}, "by_tool": {"A": 1, "B": 1},
  "findings": [{
    "key": "c", "ruleId": "R", "severity": "HIGH",
    "location": "./src/main.py:7", "message": "x",
    "tools": ["Semgrep", "Bandit"], "sources": []
  }]
}
JSON
PR_OUT2="$("$ROOT/scripts/pr-report.sh" "$PR_TMP/findings2.json" "$PR_TMP/c2.md" annotations 2>&1)"
if printf '%s\n' "$PR_OUT2" | grep -q '::error file=src/main.py,line=7'; then
  echo "  PASS  pr annotation strips ./ prefix"
  PASS=$((PASS + 1))
else
  echo "  FAIL  pr annotation ./ prefix"
  FAIL=$((FAIL + 1))
fi
if printf '%s\n' "$PR_OUT2" | grep -q 'title=\[Semgrep/Bandit\]'; then
  echo "  PASS  pr annotation multi-tool title"
  PASS=$((PASS + 1))
else
  echo "  FAIL  pr annotation multi-tool title"
  FAIL=$((FAIL + 1))
fi
rm -rf "$PR_TMP"

rm -rf "$ART" "$DEST_ROOT"

echo
echo "== resolve-scan-scope / filter-changed-files =="

SCOPE_TMP="$(mktemp -d)"
# Classification uses SCANKIT_CHANGED_FILES (no git) for speed; one git smoke at end.
write_list() { printf '%s\n' "$@" >"$SCOPE_TMP/list.txt"; }

write_list "python/app.py"
rm -f /tmp/gh-scope-out
env GITHUB_OUTPUT=/tmp/gh-scope-out SCANKIT_CHANGED_FILES="$SCOPE_TMP/list.txt" \
  "$ROOT/scripts/resolve-scan-scope.sh" auto pull_request "" "" "$SCOPE_TMP/out-py" >/dev/null
assert_eq "py-only scan_scope" "diff" "$(grep '^scan_scope=' /tmp/gh-scope-out | cut -d= -f2)"
assert_eq "py-only scope_sast" "true" "$(grep '^scope_sast=' /tmp/gh-scope-out | cut -d= -f2)"
assert_eq "py-only scope_python_code" "true" "$(grep '^scope_python_code=' /tmp/gh-scope-out | cut -d= -f2)"
assert_eq "py-only scope_go_code" "false" "$(grep '^scope_go_code=' /tmp/gh-scope-out | cut -d= -f2)"
assert_eq "py-only scope_js_code" "false" "$(grep '^scope_js_code=' /tmp/gh-scope-out | cut -d= -f2)"
assert_eq "py-only scope_sca" "false" "$(grep '^scope_sca=' /tmp/gh-scope-out | cut -d= -f2)"
assert_eq "py-only scope_dockerfile" "false" "$(grep '^scope_dockerfile=' /tmp/gh-scope-out | cut -d= -f2)"
FILTERED=$("$ROOT/scripts/filter-changed-files.sh" "$SCOPE_TMP/out-py/changed-files.txt" '\.py$')
assert_eq "filter py" "python/app.py" "$FILTERED"

write_list "README.md"
rm -f /tmp/gh-scope-out
env GITHUB_OUTPUT=/tmp/gh-scope-out SCANKIT_CHANGED_FILES="$SCOPE_TMP/list.txt" \
  "$ROOT/scripts/resolve-scan-scope.sh" auto pull_request "" "" "$SCOPE_TMP/out-readme" >/dev/null
assert_eq "readme scope_sast" "false" "$(grep '^scope_sast=' /tmp/gh-scope-out | cut -d= -f2)"
assert_eq "readme scope_secrets" "true" "$(grep '^scope_secrets=' /tmp/gh-scope-out | cut -d= -f2)"
assert_eq "readme scope_sca" "false" "$(grep '^scope_sca=' /tmp/gh-scope-out | cut -d= -f2)"

write_list "python/requirements.txt"
rm -f /tmp/gh-scope-out
env GITHUB_OUTPUT=/tmp/gh-scope-out SCANKIT_CHANGED_FILES="$SCOPE_TMP/list.txt" \
  "$ROOT/scripts/resolve-scan-scope.sh" auto pull_request "" "" "$SCOPE_TMP/out-reqs" >/dev/null
assert_eq "reqs scope_python_manifest" "true" "$(grep '^scope_python_manifest=' /tmp/gh-scope-out | cut -d= -f2)"
assert_eq "reqs scope_sca" "true" "$(grep '^scope_sca=' /tmp/gh-scope-out | cut -d= -f2)"

write_list "pkg/main.go"
rm -f /tmp/gh-scope-out
env GITHUB_OUTPUT=/tmp/gh-scope-out SCANKIT_CHANGED_FILES="$SCOPE_TMP/list.txt" \
  "$ROOT/scripts/resolve-scan-scope.sh" auto pull_request "" "" "$SCOPE_TMP/out-go" >/dev/null
assert_eq "go-only scope_go_code" "true" "$(grep '^scope_go_code=' /tmp/gh-scope-out | cut -d= -f2)"
assert_eq "go-only scope_go_manifest" "false" "$(grep '^scope_go_manifest=' /tmp/gh-scope-out | cut -d= -f2)"
assert_eq "go-only scope_python_code" "false" "$(grep '^scope_python_code=' /tmp/gh-scope-out | cut -d= -f2)"

write_list "web/app.ts"
rm -f /tmp/gh-scope-out
env GITHUB_OUTPUT=/tmp/gh-scope-out SCANKIT_CHANGED_FILES="$SCOPE_TMP/list.txt" \
  "$ROOT/scripts/resolve-scan-scope.sh" auto pull_request "" "" "$SCOPE_TMP/out-ts" >/dev/null
assert_eq "ts-only scope_js_code" "true" "$(grep '^scope_js_code=' /tmp/gh-scope-out | cut -d= -f2)"
assert_eq "ts-only scope_python_code" "false" "$(grep '^scope_python_code=' /tmp/gh-scope-out | cut -d= -f2)"

rm -f /tmp/gh-scope-out
env GITHUB_OUTPUT=/tmp/gh-scope-out \
  "$ROOT/scripts/resolve-scan-scope.sh" auto push "" "" "$SCOPE_TMP/out-full" >/dev/null
assert_eq "push auto is full" "full" "$(grep '^scan_scope=' /tmp/gh-scope-out | cut -d= -f2)"
assert_eq "full scope_sast" "true" "$(grep '^scope_sast=' /tmp/gh-scope-out | cut -d= -f2)"

# Smoke: real git diff path still works
pushd "$SCOPE_TMP" >/dev/null
git init -q
git config user.email "test@example.com"
git config user.name "test"
mkdir -p python
echo 'print(1)' > python/app.py
git add -A && git commit -qm base
BASE=$(git rev-parse HEAD)
echo 'print(2)' >> python/app.py
git add -A && git commit -qm py
HEAD_PY=$(git rev-parse HEAD)
rm -f /tmp/gh-scope-out
env GITHUB_OUTPUT=/tmp/gh-scope-out \
  "$ROOT/scripts/resolve-scan-scope.sh" diff pull_request "$BASE" "$HEAD_PY" "$SCOPE_TMP/out-git" >/dev/null
assert_eq "git-diff lists py" "python/app.py" "$(tr '\n' ' ' <"$SCOPE_TMP/out-git/changed-files.txt" | sed 's/ *$//')"
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

# Cache pinned actionlint under ~/.cache/scankit (or $SCANKIT_CACHE) to avoid a
# network download on every run. Set SKIP_ACTIONLINT=1 to skip entirely.
AL_VERSION=1.7.7
CACHE_ROOT="${SCANKIT_CACHE:-${HOME}/.cache/scankit}"
mkdir -p "$CACHE_ROOT"
ACTIONLINT_BIN="${CACHE_ROOT}/actionlint-${AL_VERSION}"
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64) ARCH=amd64 ;;
  arm64|aarch64) ARCH=arm64 ;;
esac

if [[ "${SKIP_ACTIONLINT:-}" == "1" ]]; then
  echo "  PASS  actionlint skipped (SKIP_ACTIONLINT=1)"
  PASS=$((PASS + 1))
elif [[ -x "$ACTIONLINT_BIN" ]] || {
  AL_TGZ="${CACHE_ROOT}/actionlint_${AL_VERSION}_${OS}_${ARCH}.tar.gz"
  AL_URL="https://github.com/rhysd/actionlint/releases/download/v${AL_VERSION}/actionlint_${AL_VERSION}_${OS}_${ARCH}.tar.gz"
  curl -fsSL "$AL_URL" -o "$AL_TGZ" &&
  if [[ "$OS" == "linux" && "$ARCH" == "amd64" ]]; then
    bash scripts/verify-sha256.sh "$AL_TGZ" 023070a287cd8cccd71515fedc843f1985bf96c436b7effaecce67290e7e0757
  fi &&
  tar -xzf "$AL_TGZ" -C "$CACHE_ROOT" actionlint &&
  mv -f "${CACHE_ROOT}/actionlint" "$ACTIONLINT_BIN" &&
  chmod +x "$ACTIONLINT_BIN"
}; then
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
  echo "  FAIL  could not download/cache actionlint"
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

if grep -A20 'name: sast-gosec' .github/workflows/reusable-sast.yml | grep -q 'scope_go_code'; then
  echo "  PASS  gosec runs when Go is in the diff"
  PASS=$((PASS + 1))
else
  echo "  FAIL  gosec still hard-skips diff"
  FAIL=$((FAIL + 1))
fi

if grep -A25 'name: sast-codeql-langs' .github/workflows/reusable-sast.yml | grep -q 'scope_python_code'; then
  echo "  PASS  codeql runs per-language on diff"
  PASS=$((PASS + 1))
else
  echo "  FAIL  codeql still hard-skips diff"
  FAIL=$((FAIL + 1))
fi

if grep -A8 'name: supply-scorecard' .github/workflows/reusable-supply-chain.yml | grep -q "scan-scope != 'diff')"; then
  echo "  PASS  scorecard still skips pull-request diffs"
  PASS=$((PASS + 1))
else
  echo "  FAIL  scorecard should remain skipped in diff mode"
  FAIL=$((FAIL + 1))
fi

if grep -A8 'name: sca-govulncheck' .github/workflows/reusable-sca.yml | grep -q 'scope_go_code'; then
  echo "  PASS  govulncheck runs on Go source diffs"
  PASS=$((PASS + 1))
else
  echo "  FAIL  govulncheck missing scope_go_code trigger"
  FAIL=$((FAIL + 1))
fi

echo
echo "Results: $PASS passed, $FAIL failed"
if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi
echo "All tests passed."
