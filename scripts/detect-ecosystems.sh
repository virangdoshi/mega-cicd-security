#!/usr/bin/env bash
# Detect ecosystems present in a repository checkout.
# Writes boolean flags to GITHUB_OUTPUT (when set) and ecosystems.json.
set -euo pipefail

ROOT="${1:-.}"
cd "$ROOT"

out_file="${GITHUB_OUTPUT:-/dev/null}"
json_path="${2:-ecosystems.json}"

flag() {
  local name="$1"
  local value="$2"
  echo "${name}=${value}" >>"$out_file"
  echo "${name}=${value}"
}

# Usage: found -name '*.py' -o -name 'go.mod'
found() {
  find . -type f \( "$@" \) \
    ! -path './.git/*' \
    ! -path './node_modules/*' \
    ! -path './.venv/*' \
    ! -path './vendor/*' \
    ! -path './security-results/*' \
    2>/dev/null | head -n 1 | grep -q .
}

has_python=false
has_go=false
has_java=false
has_ruby=false
has_node=false
has_rust=false
has_php=false
has_dotnet=false
has_docker=false
has_terraform=false
has_k8s=false
has_cloudformation=false
has_openapi=false
has_graphql=false
has_binary=false
has_actions=false
has_shell=false
has_generic_code=false

if found -name '*.py' -o -name 'pyproject.toml' -o -name 'Pipfile' -o -name 'requirements.txt' -o -name 'requirements*.txt'; then
  has_python=true
fi
if found -name 'go.mod' -o -name '*.go'; then
  has_go=true
fi
if found -name 'pom.xml' -o -name 'build.gradle' -o -name 'build.gradle.kts' -o -name '*.java'; then
  has_java=true
fi
if found -name 'Gemfile' -o -name '*.rb'; then
  has_ruby=true
fi
if found -name 'package.json' -o -name 'pnpm-lock.yaml' -o -name 'yarn.lock'; then
  has_node=true
fi
if found -name 'Cargo.toml'; then
  has_rust=true
fi
if found -name 'composer.json' -o -name '*.php'; then
  has_php=true
fi
if found -name '*.csproj' -o -name '*.sln' -o -name '*.fsproj'; then
  has_dotnet=true
fi
if found -name 'Dockerfile' -o -name 'Dockerfile.*' -o -name '*.dockerfile' \
  -o -name 'docker-compose.yml' -o -name 'docker-compose.yaml' \
  -o -name 'compose.yml' -o -name 'compose.yaml'; then
  has_docker=true
fi
if found -name '*.tf' -o -name '*.tf.json'; then
  has_terraform=true
fi
if found -name 'Chart.yaml' -o -name 'Chart.yml'; then
  has_k8s=true
fi
# Heuristic: Kubernetes manifests (null-delimited; sample first 200 files)
k8s_sample=()
while IFS= read -r -d '' f && ((${#k8s_sample[@]} < 200)); do
  k8s_sample+=("$f")
done < <(find . -type f \( -name '*.yaml' -o -name '*.yml' \) \
  ! -path './.git/*' ! -path './node_modules/*' -print0 2>/dev/null)
if ((${#k8s_sample[@]})) && printf '%s\0' "${k8s_sample[@]}" \
  | xargs -0 grep -l -E '^apiVersion:' 2>/dev/null \
  | head -n 1 | grep -q .; then
  has_k8s=true
fi
cfn_sample=()
while IFS= read -r -d '' f && ((${#cfn_sample[@]} < 200)); do
  cfn_sample+=("$f")
done < <(find . -type f \( -name '*.yaml' -o -name '*.yml' -o -name '*.json' \) \
  ! -path './.git/*' -print0 2>/dev/null)
if found -name 'cdk.json' || { ((${#cfn_sample[@]})) && printf '%s\0' "${cfn_sample[@]}" \
  | xargs -0 grep -l -Ei 'AWSTemplateFormatVersion|aws::cloudformation' 2>/dev/null \
  | head -n 1 | grep -q .; }; then
  has_cloudformation=true
fi
if find . -type f \( \
  -iname 'openapi*.yml' -o -iname 'openapi*.yaml' -o -iname 'openapi*.json' \
  -o -iname 'swagger*.yml' -o -iname 'swagger*.yaml' -o -iname 'swagger*.json' \
  -o -iname 'asyncapi*.yml' -o -iname 'asyncapi*.yaml' -o -iname 'asyncapi*.json' \
\) ! -path './.git/*' 2>/dev/null | head -n 1 | grep -q .; then
  has_openapi=true
fi
if found -name '*.graphql' -o -name '*.gql'; then
  has_graphql=true
fi
if [[ -d .github/workflows ]] && find .github/workflows -type f \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null | head -n 1 | grep -q .; then
  has_actions=true
fi
if found -name '*.sh' -o -name '*.bash' -o -name '*.ksh' -o -name '*.zsh'; then
  has_shell=true
fi
# Shebang heuristic (limited sample for speed; null-delimited)
shebang_sample=()
while IFS= read -r -d '' f && ((${#shebang_sample[@]} < 500)); do
  shebang_sample+=("$f")
done < <(find . -type f ! -path './.git/*' ! -path './node_modules/*' -print0 2>/dev/null)
if ((${#shebang_sample[@]})) && printf '%s\0' "${shebang_sample[@]}" \
  | xargs -0 grep -l -E '^#!/bin/(sh|bash)|#!/usr/bin/env bash|^#!/usr/bin/env sh' 2>/dev/null \
  | head -n 1 | grep -q .; then
  has_shell=true
fi
# Binary magic (sample)
while IFS= read -r f; do
  if file -b "$f" 2>/dev/null | grep -Eqi 'ELF|PE32|Mach-O|executable'; then
    has_binary=true
    break
  fi
done < <(find . -type f ! -path './.git/*' ! -path './node_modules/*' 2>/dev/null | head -n 100)

if $has_python || $has_go || $has_java || $has_ruby || $has_node || $has_rust || $has_php || $has_dotnet || $has_shell || $has_docker || $has_terraform || $has_k8s || $has_actions; then
  has_generic_code=true
fi
# Any non-trivial checkout
if find . -type f ! -path './.git/*' 2>/dev/null | head -n 5 | grep -q .; then
  has_generic_code=true
fi

flag has_python "$has_python"
flag has_go "$has_go"
flag has_java "$has_java"
flag has_ruby "$has_ruby"
flag has_node "$has_node"
flag has_rust "$has_rust"
flag has_php "$has_php"
flag has_dotnet "$has_dotnet"
flag has_docker "$has_docker"
flag has_terraform "$has_terraform"
flag has_k8s "$has_k8s"
flag has_cloudformation "$has_cloudformation"
flag has_openapi "$has_openapi"
flag has_graphql "$has_graphql"
flag has_binary "$has_binary"
flag has_actions "$has_actions"
flag has_shell "$has_shell"
flag has_generic_code "$has_generic_code"

cat >"$json_path" <<EOF
{
  "has_python": ${has_python},
  "has_go": ${has_go},
  "has_java": ${has_java},
  "has_ruby": ${has_ruby},
  "has_node": ${has_node},
  "has_rust": ${has_rust},
  "has_php": ${has_php},
  "has_dotnet": ${has_dotnet},
  "has_docker": ${has_docker},
  "has_terraform": ${has_terraform},
  "has_k8s": ${has_k8s},
  "has_cloudformation": ${has_cloudformation},
  "has_openapi": ${has_openapi},
  "has_graphql": ${has_graphql},
  "has_binary": ${has_binary},
  "has_actions": ${has_actions},
  "has_shell": ${has_shell},
  "has_generic_code": ${has_generic_code}
}
EOF

echo "Wrote $json_path"
cat "$json_path"
