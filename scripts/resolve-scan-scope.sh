#!/usr/bin/env bash
# Resolve scan scope (full vs diff) and classify changed files for category gating.
#
# Usage:
#   resolve-scan-scope.sh <requested_mode> <event_name> [base_sha] [head_sha] [out_dir]
#
# requested_mode: auto | diff | full
# Writes:
#   - changed-files.txt (newline-separated paths that exist on disk; empty in full mode)
#   - scope.json
#   - GITHUB_OUTPUT flags when set
set -euo pipefail

REQUESTED="${1:-auto}"
EVENT_NAME="${2:-}"
BASE_SHA="${3:-}"
HEAD_SHA="${4:-}"
OUT_DIR="${5:-.}"

mkdir -p "$OUT_DIR"
CHANGED_FILE="$OUT_DIR/changed-files.txt"
SCOPE_JSON="$OUT_DIR/scope.json"
out_file="${GITHUB_OUTPUT:-/dev/null}"

flag() {
  local name="$1"
  local value="$2"
  echo "${name}=${value}" >>"$out_file"
}

# Resolve effective mode
MODE="$REQUESTED"
if [[ "$MODE" == "auto" ]]; then
  if [[ "$EVENT_NAME" == "pull_request" || "$EVENT_NAME" == "pull_request_target" ]]; then
    MODE="diff"
  else
    MODE="full"
  fi
fi
if [[ "$MODE" != "diff" && "$MODE" != "full" ]]; then
  echo "Invalid scan-scope mode: $MODE (use auto|diff|full)" >&2
  exit 1
fi

: >"$CHANGED_FILE"
changed_count=0

if [[ "$MODE" == "diff" ]]; then
  if [[ -z "$BASE_SHA" || -z "$HEAD_SHA" ]]; then
    echo "diff mode requires base and head SHAs" >&2
    exit 1
  fi
  # List files added/modified (not deleted) between base and head
  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    if [[ -e "$path" || -L "$path" ]]; then
      printf '%s\n' "$path" >>"$CHANGED_FILE"
      changed_count=$((changed_count + 1))
    fi
  done < <(git diff --name-only --diff-filter=ACMR "${BASE_SHA}...${HEAD_SHA}" 2>/dev/null || git diff --name-only --diff-filter=ACMR "${BASE_SHA}" "${HEAD_SHA}")
fi

match_any() {
  # Returns 0 if any line in CHANGED_FILE matches the extended regex
  local re="$1"
  if [[ "$MODE" == "full" ]]; then
    return 0
  fi
  if [[ ! -s "$CHANGED_FILE" ]]; then
    return 1
  fi
  grep -E -q "$re" "$CHANGED_FILE"
}

# Category relevance (full mode => all true)
scope_sast=false
scope_secrets=false
scope_sca=false
scope_iac=false
scope_container=false
scope_api=false
scope_privacy=false
scope_malware=false
scope_meta=false
scope_sbom=false
scope_supply=false
# Finer triggers for tools that cannot path-filter
scope_go_code=false
scope_ruby_code=false
scope_java_code=false
scope_python_manifest=false
scope_go_manifest=false
scope_node_manifest=false
scope_rust_manifest=false
scope_ruby_manifest=false
scope_php_manifest=false
scope_dotnet_manifest=false
scope_dockerfile=false
scope_workflows=false
scope_any_manifest=false

if [[ "$MODE" == "full" ]]; then
  scope_sast=true
  scope_secrets=true
  scope_sca=true
  scope_iac=true
  scope_container=true
  scope_api=true
  scope_privacy=true
  scope_malware=true
  scope_meta=true
  scope_sbom=true
  scope_supply=true
  scope_go_code=true
  scope_ruby_code=true
  scope_java_code=true
  scope_python_manifest=true
  scope_go_manifest=true
  scope_node_manifest=true
  scope_rust_manifest=true
  scope_ruby_manifest=true
  scope_php_manifest=true
  scope_dotnet_manifest=true
  scope_dockerfile=true
  scope_workflows=true
  scope_any_manifest=true
else
  # Any changed file can carry secrets / privacy / malware bait
  if [[ "$changed_count" -gt 0 ]]; then
    scope_secrets=true
    scope_privacy=true
    scope_malware=true
  fi

  if match_any '\.(py|pyi|go|java|kt|kts|rb|js|jsx|mjs|cjs|ts|tsx|php|cs|fs|rs|c|cc|cpp|h|hpp|swift|scala|sh|bash|zsh|ksh)$'; then
    scope_sast=true
  fi
  if match_any '\.go$'; then scope_go_code=true; fi
  if match_any '\.rb$'; then scope_ruby_code=true; fi
  if match_any '\.(java|kt|kts)$'; then scope_java_code=true; fi

  if match_any '(^|/)(requirements([^/]*)\.txt|Pipfile|Pipfile\.lock|pyproject\.toml|poetry\.lock|go\.mod|go\.sum|package\.json|package-lock\.json|yarn\.lock|pnpm-lock\.yaml|Cargo\.toml|Cargo\.lock|Gemfile|Gemfile\.lock|composer\.json|composer\.lock|.*\.(csproj|fsproj|sln)|pom\.xml|build\.gradle(\.kts)?)$'; then
    scope_sca=true
    scope_sbom=true
    scope_supply=true
    scope_any_manifest=true
  fi
  if match_any '(^|/)(requirements([^/]*)\.txt|Pipfile|Pipfile\.lock|pyproject\.toml|poetry\.lock)$'; then
    scope_python_manifest=true
  fi
  if match_any '(^|/)(go\.mod|go\.sum)$'; then scope_go_manifest=true; fi
  if match_any '(^|/)(package\.json|package-lock\.json|yarn\.lock|pnpm-lock\.yaml)$'; then
    scope_node_manifest=true
  fi
  if match_any '(^|/)(Cargo\.toml|Cargo\.lock)$'; then scope_rust_manifest=true; fi
  if match_any '(^|/)(Gemfile|Gemfile\.lock)$'; then scope_ruby_manifest=true; fi
  if match_any '(^|/)(composer\.json|composer\.lock)$'; then scope_php_manifest=true; fi
  if match_any '\.(csproj|fsproj|sln)$'; then scope_dotnet_manifest=true; fi

  if match_any '\.(tf|tf\.json)$|(^|/)(Chart\.ya?ml)$|^apiVersion:'; then
    : # apiVersion match on filename won't work; use yaml/yml for k8s heuristic below
  fi
  if match_any '\.(tf|tf\.json)$|(^|/)Chart\.ya?ml$|\.(ya?ml)$'; then
    # YAML may be k8s/cfn; gate IaC broadly on yaml/tf
    scope_iac=true
  fi
  # Narrower: terraform always; k8s/cfn if yaml changed (tools filter further)
  if match_any '\.(tf|tf\.json)$|(^|/)Chart\.ya?ml$'; then scope_iac=true; fi

  if match_any '(^|/)Dockerfile(\.|$)|(^|/)[^/]*\.dockerfile$|(^|/)(docker-compose|compose)\.ya?ml$'; then
    scope_container=true
    scope_dockerfile=true
  fi

  if match_any '(^|/)(openapi|swagger|asyncapi)[^/]*\.(ya?ml|json)$|\.(graphql|gql)$'; then
    scope_api=true
  fi

  if match_any '(^|/)\.github/workflows/.*\.(ya?ml)$'; then
    scope_meta=true
    scope_workflows=true
    scope_supply=true
  fi

  if match_any '(^|/)SECURITY-INSIGHTS\.ya?ml$'; then
    scope_supply=true
  fi
fi

has_changed_files=false
if [[ "$changed_count" -gt 0 ]]; then
  has_changed_files=true
fi

flag scan_scope "$MODE"
flag changed_file_count "$changed_count"
flag has_changed_files "$has_changed_files"
flag scope_sast "$scope_sast"
flag scope_secrets "$scope_secrets"
flag scope_sca "$scope_sca"
flag scope_iac "$scope_iac"
flag scope_container "$scope_container"
flag scope_api "$scope_api"
flag scope_privacy "$scope_privacy"
flag scope_malware "$scope_malware"
flag scope_meta "$scope_meta"
flag scope_sbom "$scope_sbom"
flag scope_supply "$scope_supply"
flag scope_go_code "$scope_go_code"
flag scope_ruby_code "$scope_ruby_code"
flag scope_java_code "$scope_java_code"
flag scope_python_manifest "$scope_python_manifest"
flag scope_go_manifest "$scope_go_manifest"
flag scope_node_manifest "$scope_node_manifest"
flag scope_rust_manifest "$scope_rust_manifest"
flag scope_ruby_manifest "$scope_ruby_manifest"
flag scope_php_manifest "$scope_php_manifest"
flag scope_dotnet_manifest "$scope_dotnet_manifest"
flag scope_dockerfile "$scope_dockerfile"
flag scope_workflows "$scope_workflows"
flag scope_any_manifest "$scope_any_manifest"

cat >"$SCOPE_JSON" <<EOF
{
  "scan_scope": "$MODE",
  "changed_file_count": $changed_count,
  "has_changed_files": $has_changed_files,
  "scope_sast": $scope_sast,
  "scope_secrets": $scope_secrets,
  "scope_sca": $scope_sca,
  "scope_iac": $scope_iac,
  "scope_container": $scope_container,
  "scope_api": $scope_api,
  "scope_privacy": $scope_privacy,
  "scope_malware": $scope_malware,
  "scope_meta": $scope_meta,
  "scope_sbom": $scope_sbom,
  "scope_supply": $scope_supply,
  "scope_go_code": $scope_go_code,
  "scope_ruby_code": $scope_ruby_code,
  "scope_java_code": $scope_java_code,
  "scope_python_manifest": $scope_python_manifest,
  "scope_go_manifest": $scope_go_manifest,
  "scope_node_manifest": $scope_node_manifest,
  "scope_rust_manifest": $scope_rust_manifest,
  "scope_ruby_manifest": $scope_ruby_manifest,
  "scope_php_manifest": $scope_php_manifest,
  "scope_dotnet_manifest": $scope_dotnet_manifest,
  "scope_dockerfile": $scope_dockerfile,
  "scope_workflows": $scope_workflows,
  "scope_any_manifest": $scope_any_manifest
}
EOF

echo "Resolved scan_scope=$MODE changed_file_count=$changed_count"
cat "$SCOPE_JSON"
