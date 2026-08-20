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
assert_flags "python" "$OUT" has_python true has_go false has_java false has_generic_code true
rm -f "$OUT"

OUT=$(run_detect tests/fixtures/go-app)
assert_flags "go" "$OUT" has_go true has_python false
rm -f "$OUT"

OUT=$(run_detect tests/fixtures/node-app)
assert_flags "node" "$OUT" has_node true has_python false
rm -f "$OUT"

OUT=$(run_detect tests/fixtures/docker-app)
assert_flags "docker" "$OUT" has_docker true
rm -f "$OUT"

OUT=$(run_detect tests/fixtures/openapi-app)
assert_flags "openapi" "$OUT" has_openapi true has_graphql false
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

OUT=$(run_detect tests/fixtures/java-app)
assert_flags "java" "$OUT" has_java true has_python false has_go false
rm -f "$OUT"

OUT=$(run_detect tests/fixtures/ruby-app)
assert_flags "ruby" "$OUT" has_ruby true has_java false
rm -f "$OUT"

OUT=$(run_detect tests/fixtures/rust-app)
assert_flags "rust" "$OUT" has_rust true has_node false
rm -f "$OUT"

OUT=$(run_detect tests/fixtures/php-app)
assert_flags "php" "$OUT" has_php true has_dotnet false
rm -f "$OUT"

OUT=$(run_detect tests/fixtures/dotnet-app)
assert_flags "dotnet" "$OUT" has_dotnet true has_php false
rm -f "$OUT"

OUT=$(run_detect tests/fixtures/terraform-app)
assert_flags "terraform" "$OUT" has_terraform true has_k8s false
rm -f "$OUT"

OUT=$(run_detect tests/fixtures/k8s-app)
assert_flags "k8s" "$OUT" has_k8s true has_terraform false has_cloudformation false
rm -f "$OUT"

OUT=$(run_detect tests/fixtures/cfn-app)
assert_flags "cfn" "$OUT" has_cloudformation true has_k8s false
rm -f "$OUT"

OUT=$(run_detect tests/fixtures/graphql-app)
assert_flags "graphql" "$OUT" has_graphql true has_openapi false
rm -f "$OUT"

OUT=$(run_detect tests/fixtures/binary-app)
assert_flags "binary" "$OUT" has_binary true
rm -f "$OUT"

OUT=$(run_detect "$ROOT")
assert_flags "self" "$OUT" has_actions true has_shell true has_generic_code true
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

cat >"$PR_TMP/empty.json" <<'JSON'
{"total_raw": 0, "total_unique": 0, "by_severity": {}, "by_tool": {}, "findings": []}
JSON
PR_OUT3="$("$ROOT/scripts/pr-report.sh" "$PR_TMP/empty.json" "$PR_TMP/c3.md" comment 2>&1)"
if printf '%s\n' "$PR_OUT3" | grep -q '::error'; then
  echo "  FAIL  comment mode should not emit annotations"
  FAIL=$((FAIL + 1))
else
  echo "  PASS  comment mode has no annotations"
  PASS=$((PASS + 1))
fi
if grep -q 'Unique SARIF findings: \*\*0\*\*' "$PR_TMP/c3.md"; then
  echo "  PASS  empty findings comment"
  PASS=$((PASS + 1))
else
  echo "  FAIL  empty findings comment"
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

printf '%s\n' "python/app.py" "go/main.go" "Dockerfile" ".github/workflows/ci.yml" "missing.xyz" >"$SCOPE_TMP/mixed.txt"
FILTERED=$("$ROOT/scripts/filter-changed-files.sh" "$SCOPE_TMP/mixed.txt" '\.py$' '\.go$')
assert_eq "filter multi-regex" "$(printf '%s\n' python/app.py go/main.go)" "$FILTERED"
FILTERED=$("$ROOT/scripts/filter-changed-files.sh" "$SCOPE_TMP/mixed.txt")
assert_eq "filter no-regex copies list" "$(cat "$SCOPE_TMP/mixed.txt")" "$FILTERED"
: >"$SCOPE_TMP/empty.txt"
FILTERED=$("$ROOT/scripts/filter-changed-files.sh" "$SCOPE_TMP/empty.txt" '\.py$')
assert_eq "filter empty list" "" "$FILTERED"
set +e
"$ROOT/scripts/filter-changed-files.sh" "$SCOPE_TMP/no-such.txt" '\.py$' >/dev/null 2>&1
FILTER_RC=$?
set -e
assert_eq "filter missing list exits 1" "1" "$FILTER_RC"

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

write_list "Dockerfile"
rm -f /tmp/gh-scope-out
env GITHUB_OUTPUT=/tmp/gh-scope-out SCANKIT_CHANGED_FILES="$SCOPE_TMP/list.txt" \
  "$ROOT/scripts/resolve-scan-scope.sh" auto pull_request "" "" "$SCOPE_TMP/out-df" >/dev/null
assert_eq "dockerfile scope_dockerfile" "true" "$(grep '^scope_dockerfile=' /tmp/gh-scope-out | cut -d= -f2)"
assert_eq "dockerfile scope_container" "true" "$(grep '^scope_container=' /tmp/gh-scope-out | cut -d= -f2)"
assert_eq "dockerfile scope_sast" "false" "$(grep '^scope_sast=' /tmp/gh-scope-out | cut -d= -f2)"

write_list "infra/main.tf"
rm -f /tmp/gh-scope-out
env GITHUB_OUTPUT=/tmp/gh-scope-out SCANKIT_CHANGED_FILES="$SCOPE_TMP/list.txt" \
  "$ROOT/scripts/resolve-scan-scope.sh" auto pull_request "" "" "$SCOPE_TMP/out-tf" >/dev/null
assert_eq "tf scope_iac" "true" "$(grep '^scope_iac=' /tmp/gh-scope-out | cut -d= -f2)"

write_list "k8s/deploy.yaml"
rm -f /tmp/gh-scope-out
env GITHUB_OUTPUT=/tmp/gh-scope-out SCANKIT_CHANGED_FILES="$SCOPE_TMP/list.txt" \
  "$ROOT/scripts/resolve-scan-scope.sh" auto pull_request "" "" "$SCOPE_TMP/out-yaml" >/dev/null
assert_eq "k8s yaml scope_iac" "true" "$(grep '^scope_iac=' /tmp/gh-scope-out | cut -d= -f2)"

write_list ".github/workflows/ci.yml"
rm -f /tmp/gh-scope-out
env GITHUB_OUTPUT=/tmp/gh-scope-out SCANKIT_CHANGED_FILES="$SCOPE_TMP/list.txt" \
  "$ROOT/scripts/resolve-scan-scope.sh" auto pull_request "" "" "$SCOPE_TMP/out-wf" >/dev/null
assert_eq "workflows scope_workflows" "true" "$(grep '^scope_workflows=' /tmp/gh-scope-out | cut -d= -f2)"
assert_eq "workflows scope_meta" "true" "$(grep '^scope_meta=' /tmp/gh-scope-out | cut -d= -f2)"
assert_eq "workflows scope_iac" "false" "$(grep '^scope_iac=' /tmp/gh-scope-out | cut -d= -f2)"

write_list "api/openapi.yaml"
rm -f /tmp/gh-scope-out
env GITHUB_OUTPUT=/tmp/gh-scope-out SCANKIT_CHANGED_FILES="$SCOPE_TMP/list.txt" \
  "$ROOT/scripts/resolve-scan-scope.sh" auto pull_request "" "" "$SCOPE_TMP/out-api" >/dev/null
assert_eq "openapi scope_api" "true" "$(grep '^scope_api=' /tmp/gh-scope-out | cut -d= -f2)"

write_list "api/schema.graphql"
rm -f /tmp/gh-scope-out
env GITHUB_OUTPUT=/tmp/gh-scope-out SCANKIT_CHANGED_FILES="$SCOPE_TMP/list.txt" \
  "$ROOT/scripts/resolve-scan-scope.sh" auto pull_request "" "" "$SCOPE_TMP/out-gql" >/dev/null
assert_eq "graphql scope_api" "true" "$(grep '^scope_api=' /tmp/gh-scope-out | cut -d= -f2)"

write_list "src/App.java"
rm -f /tmp/gh-scope-out
env GITHUB_OUTPUT=/tmp/gh-scope-out SCANKIT_CHANGED_FILES="$SCOPE_TMP/list.txt" \
  "$ROOT/scripts/resolve-scan-scope.sh" auto pull_request "" "" "$SCOPE_TMP/out-java" >/dev/null
assert_eq "java scope_java_code" "true" "$(grep '^scope_java_code=' /tmp/gh-scope-out | cut -d= -f2)"
assert_eq "java scope_sast" "true" "$(grep '^scope_sast=' /tmp/gh-scope-out | cut -d= -f2)"

write_list "app/users_controller.rb"
rm -f /tmp/gh-scope-out
env GITHUB_OUTPUT=/tmp/gh-scope-out SCANKIT_CHANGED_FILES="$SCOPE_TMP/list.txt" \
  "$ROOT/scripts/resolve-scan-scope.sh" auto pull_request "" "" "$SCOPE_TMP/out-rb" >/dev/null
assert_eq "ruby scope_ruby_code" "true" "$(grep '^scope_ruby_code=' /tmp/gh-scope-out | cut -d= -f2)"

: >"$SCOPE_TMP/none.txt"
rm -f /tmp/gh-scope-out
env GITHUB_OUTPUT=/tmp/gh-scope-out SCANKIT_CHANGED_FILES="$SCOPE_TMP/none.txt" \
  "$ROOT/scripts/resolve-scan-scope.sh" auto pull_request "" "" "$SCOPE_TMP/out-none" >/dev/null
assert_eq "empty diff scope_secrets" "false" "$(grep '^scope_secrets=' /tmp/gh-scope-out | cut -d= -f2)"
assert_eq "empty diff scope_sast" "false" "$(grep '^scope_sast=' /tmp/gh-scope-out | cut -d= -f2)"

rm -f /tmp/gh-scope-out
env GITHUB_OUTPUT=/tmp/gh-scope-out \
  "$ROOT/scripts/resolve-scan-scope.sh" auto workflow_dispatch "" "" "$SCOPE_TMP/out-dispatch" >/dev/null
assert_eq "dispatch auto is full" "full" "$(grep '^scan_scope=' /tmp/gh-scope-out | cut -d= -f2)"

rm -f /tmp/gh-scope-out
env GITHUB_OUTPUT=/tmp/gh-scope-out SCANKIT_CHANGED_FILES="$SCOPE_TMP/list.txt" \
  "$ROOT/scripts/resolve-scan-scope.sh" auto pull_request_target "" "" "$SCOPE_TMP/out-prt" >/dev/null
assert_eq "pull_request_target auto is diff" "diff" "$(grep '^scan_scope=' /tmp/gh-scope-out | cut -d= -f2)"

set +e
"$ROOT/scripts/resolve-scan-scope.sh" nope pull_request "" "" "$SCOPE_TMP/out-bad" >/dev/null 2>&1
SCOPE_RC=$?
set -e
assert_eq "invalid scan-scope exits 1" "1" "$SCOPE_RC"

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
echo "== verify-sha256 =="
HASH_TMP="$(mktemp)"
echo "scankit-hash-test" >"$HASH_TMP"
WANT="$(shasum -a 256 "$HASH_TMP" | awk '{print $1}')"
if "$ROOT/scripts/verify-sha256.sh" "$HASH_TMP" "$WANT"; then
  echo "  PASS  verify-sha256 match"
  PASS=$((PASS + 1))
else
  echo "  FAIL  verify-sha256 match"
  FAIL=$((FAIL + 1))
fi
set +e
"$ROOT/scripts/verify-sha256.sh" "$HASH_TMP" "0000000000000000000000000000000000000000000000000000000000000000" >/dev/null 2>&1
HASH_RC=$?
set -e
assert_eq "verify-sha256 mismatch exits 1" "1" "$HASH_RC"
rm -f "$HASH_TMP"

echo
echo "== scankit-root path =="
SK_ROOT="$(cd "$ROOT/.github/actions/scankit-root/../../.." && pwd)"
assert_eq "scankit-root resolves repo" "$ROOT" "$SK_ROOT"
if [[ -d "$SK_ROOT/.github/pinned" ]]; then
  echo "  PASS  scankit-root pinned dir exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL  scankit-root pinned dir missing"
  FAIL=$((FAIL + 1))
fi

echo
echo "== prepare-scan-paths =="
PREP="$(mktemp -d)"
pushd "$PREP" >/dev/null
echo 'print(1)' >app.py
echo 'package main' >main.go
printf '%s\n' app.py main.go gone.py >changed-files.txt
rm -f /tmp/gh-prep-out
env GITHUB_OUTPUT=/tmp/gh-prep-out SCAN_SCOPE=full \
  "$ROOT/scripts/prepare-scan-paths.sh" >/dev/null
assert_eq "prep full skip" "false" "$(grep '^skip=' /tmp/gh-prep-out | cut -d= -f2)"
assert_eq "prep full path_args" "." "$(grep '^path_args=' /tmp/gh-prep-out | cut -d= -f2-)"

rm -f /tmp/gh-prep-out scan-paths.txt
env GITHUB_OUTPUT=/tmp/gh-prep-out SCAN_SCOPE=diff PATTERNS='\.py$' \
  "$ROOT/scripts/prepare-scan-paths.sh" >/dev/null
assert_eq "prep diff py skip" "false" "$(grep '^skip=' /tmp/gh-prep-out | cut -d= -f2)"
assert_eq "prep diff py count" "1" "$(grep '^path_count=' /tmp/gh-prep-out | cut -d= -f2)"
assert_eq "prep diff py paths" "app.py" "$(tr '\n' ' ' <scan-paths.txt | sed 's/ *$//')"

rm -f /tmp/gh-prep-out scan-paths.txt
env GITHUB_OUTPUT=/tmp/gh-prep-out SCAN_SCOPE=diff PATTERNS='\.rb$' \
  "$ROOT/scripts/prepare-scan-paths.sh" >/dev/null
assert_eq "prep diff no-match skip" "true" "$(grep '^skip=' /tmp/gh-prep-out | cut -d= -f2)"

rm -f changed-files.txt /tmp/gh-prep-out scan-paths.txt
mkdir -p changed-files
printf '%s\n' app.py >changed-files/changed-files.txt
env GITHUB_OUTPUT=/tmp/gh-prep-out SCAN_SCOPE=diff \
  "$ROOT/scripts/prepare-scan-paths.sh" >/dev/null
assert_eq "prep nested artifact skip" "false" "$(grep '^skip=' /tmp/gh-prep-out | cut -d= -f2)"
assert_eq "prep nested artifact count" "1" "$(grep '^path_count=' /tmp/gh-prep-out | cut -d= -f2)"

rm -rf changed-files /tmp/gh-prep-out scan-paths.txt
env GITHUB_OUTPUT=/tmp/gh-prep-out SCAN_SCOPE=diff \
  "$ROOT/scripts/prepare-scan-paths.sh" >/dev/null
assert_eq "prep missing list skip" "true" "$(grep '^skip=' /tmp/gh-prep-out | cut -d= -f2)"
popd >/dev/null
rm -rf "$PREP"

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
  "$ACTIONLINT_BIN" -color -shellcheck= -pyflakes= .github/workflows/*.yml templates/*.yml
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
  .github/workflows/dependency-review.yml \
  templates/security-all.yml \
  templates/security-all-scheduled.yml \
  templates/security-sca.yml \
  templates/security-sast.yml \
  templates/security-secrets.yml \
  templates/security-container.yml \
  templates/security-iac.yml \
  templates/security-sbom.yml \
  templates/security-supply-chain.yml \
  templates/security-privacy.yml \
  templates/security-api.yml \
  templates/security-malware.yml \
  templates/security-meta.yml \
  templates/security-minimal.yml \
  templates/security-audit.yml \
  templates/security-soak.yml \
  templates/security-scan-only.yml \
  templates/org-security-policy.yml \
  scripts/resolve-profile.sh \
  scripts/load-scankit-config.sh \
  scripts/merge-scankit-settings.sh \
  scripts/run-local.sh \
  scripts/trend-summary.sh \
  scripts/export-defectdojo.sh \
  docs/quickstart.md \
  docs/config.md \
  docs/performance.md \
  CONTRIBUTING.md \
  ROADMAP.md \
  scripts/prepare-scan-paths.sh \
  scripts/verify-sha256.sh \
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

if grep -A30 'name: sca-dependency-review' .github/workflows/reusable-sca.yml | grep -q "github.event_name == 'pull_request'"; then
  echo "  PASS  dependency review is PR-only"
  PASS=$((PASS + 1))
else
  echo "  FAIL  dependency review missing pull_request gate"
  FAIL=$((FAIL + 1))
fi

if grep -A40 'name: sca-dependency-review' .github/workflows/reusable-sca.yml | grep -q "fail-on-severity == 'MEDIUM' && 'moderate'"; then
  echo "  PASS  dependency review maps MEDIUM to moderate"
  PASS=$((PASS + 1))
else
  echo "  FAIL  dependency review missing severity mapping"
  FAIL=$((FAIL + 1))
fi

if grep -q 'actions/dependency-review-action@[0-9a-f]\{40\}' .github/workflows/reusable-sca.yml; then
  echo "  PASS  dependency review action is SHA-pinned"
  PASS=$((PASS + 1))
else
  echo "  FAIL  dependency review action missing SHA pin"
  FAIL=$((FAIL + 1))
fi

if grep -A3 'permissions:' .github/workflows/reusable-security-full.yml | grep -q 'contents: write' &&
   grep -A8 'permissions:' .github/workflows/reusable-security-full.yml | grep -q 'security-events: write'; then
  echo "  PASS  full suite permission ceiling"
  PASS=$((PASS + 1))
else
  echo "  FAIL  full suite permission ceiling"
  FAIL=$((FAIL + 1))
fi

if grep -A4 'scan-scope:' .github/workflows/reusable-sast.yml | grep -q 'default: full'; then
  echo "  PASS  category sast defaults scan-scope full"
  PASS=$((PASS + 1))
else
  echo "  FAIL  category sast scan-scope default"
  FAIL=$((FAIL + 1))
fi

if grep -q 'scripts/prepare-scan-paths.sh' .github/actions/prepare-scan-paths/action.yml; then
  echo "  PASS  prepare-scan-paths action calls script"
  PASS=$((PASS + 1))
else
  echo "  FAIL  prepare-scan-paths action missing script"
  FAIL=$((FAIL + 1))
fi

echo "== resolve-profile =="
PROF_OUT="$(mktemp)"
"$ROOT/scripts/resolve-profile.sh" minimal "$PROF_OUT"
if grep -q 'run_container=false' "$PROF_OUT" && grep -q 'enable-codeql=false' "$PROF_OUT"; then
  echo "  PASS  minimal profile disables container and codeql"
  PASS=$((PASS + 1))
else
  echo "  FAIL  minimal profile flags"
  FAIL=$((FAIL + 1))
fi
"$ROOT/scripts/resolve-profile.sh" audit "$PROF_OUT"
if grep -q 'effective_scan_scope=full' "$PROF_OUT"; then
  echo "  PASS  audit profile forces full scan"
  PASS=$((PASS + 1))
else
  echo "  FAIL  audit profile scan scope"
  FAIL=$((FAIL + 1))
fi
rm -f "$PROF_OUT"

echo "== load-scankit-config =="
CFG="$(mktemp)"
cat >"$CFG" <<'EOF'
profile: soak
fail-on-severity: NONE
EOF
LOAD_OUT="$(mktemp)"
"$ROOT/scripts/load-scankit-config.sh" "$CFG" "$LOAD_OUT"
if grep -q 'profile=soak' "$LOAD_OUT" && grep -q 'fail-on-severity=NONE' "$LOAD_OUT"; then
  echo "  PASS  load-scankit-config parses yaml"
  PASS=$((PASS + 1))
else
  echo "  FAIL  load-scankit-config"
  FAIL=$((FAIL + 1))
fi
rm -f "$CFG" "$LOAD_OUT"

if grep -q 'profile:' .github/workflows/reusable-security-full.yml; then
  echo "  PASS  full suite has profile input"
  PASS=$((PASS + 1))
else
  echo "  FAIL  full suite missing profile"
  FAIL=$((FAIL + 1))
fi

if grep -q 'contents: read' .github/workflows/reusable-security-scan.yml &&
   ! grep -q 'contents: write' .github/workflows/reusable-security-scan.yml; then
  echo "  PASS  scan-only workflow read ceiling"
  PASS=$((PASS + 1))
else
  echo "  FAIL  scan-only permissions"
  FAIL=$((FAIL + 1))
fi

if grep -q 'reusable-dast.yml' .github/workflows/reusable-security-full.yml; then
  echo "  PASS  full suite wires optional dast"
  PASS=$((PASS + 1))
else
  echo "  FAIL  full suite missing dast job"
  FAIL=$((FAIL + 1))
fi

if [[ -f "$ROOT/examples/scankit-demo/README.md" ]]; then
  echo "  PASS  demo repo example present"
  PASS=$((PASS + 1))
else
  echo "  FAIL  demo repo example missing"
  FAIL=$((FAIL + 1))
fi

echo
echo "Results: $PASS passed, $FAIL failed"
if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi
echo "All tests passed."
