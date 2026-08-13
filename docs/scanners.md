# Scanner inventory

Kitchen-sink OSS tools. Overlap is intentional. With `selection-mode: detected`, tools run only when the matching ecosystem flag is true (or always for polyglot scanners when `has_generic_code` is true).

| Tool | Category | Ecosystem flag | SARIF | Default enable |
|------|----------|----------------|-------|----------------|
| OSV-Scanner | SCA | `has_generic_code` | yes | true |
| Trivy filesystem | SCA | `has_generic_code` | yes | true |
| Grype (dir) | SCA | `has_generic_code` | yes | true |
| Dependency Review | SCA | `has_generic_code` (PR only) | n/a | true |
| OWASP Dependency-Check | SCA | `has_generic_code` | no | true |
| pip-audit | SCA | `has_python` | no | true |
| govulncheck | SCA | `has_go` | no | true |
| Retire.js | SCA | `has_node` | no | true |
| CodeQL | SAST | `has_generic_code` | yes | true |
| Semgrep | SAST | `has_generic_code` | yes | true |
| Bandit | SAST | `has_python` | no | true |
| Gosec | SAST | `has_go` | yes | true |
| Brakeman | SAST | `has_ruby` | yes | true |
| SpotBugs | SAST | `has_java` | no | true |
| DevSkim | SAST | `has_generic_code` | yes | true |
| ShellCheck | SAST | `has_shell` | partial | true |
| Gitleaks | Secrets | `has_generic_code` | via action | true |
| TruffleHog | Secrets | `has_generic_code` | no | true |
| detect-secrets | Secrets | `has_generic_code` | no | true |
| secretlint | Secrets | `has_generic_code` | no | true |
| Hadolint | Container | `has_docker` | yes | true |
| Dockle | Container | `has_docker` / image | no | true |
| Trivy image | Container | `has_docker` / image | yes | true |
| Grype image | Container | `has_docker` / image | yes | true |
| Dive | Container | `has_docker` / image | no | true |
| Cosign verify | Container / Supply | image + identity inputs | no | true (skips if unset) |
| Checkov | IaC | terraform/k8s/generic | yes | true |
| KICS | IaC | terraform/k8s/generic | yes | true |
| Trivy config | IaC | terraform/k8s/generic | yes | true |
| Terrascan | IaC | terraform/k8s/generic | no | true |
| Conftest | IaC | `conftest-policy-path` set | no | true (skips if unset) |
| kube-linter | IaC | `has_k8s` | no | true |
| kubeconform | IaC | `has_k8s` | no | true |
| kube-score | IaC | `has_k8s` | no | true |
| Syft | SBOM | `has_generic_code` | n/a | true |
| Trivy SBOM | SBOM | `has_generic_code` | n/a | true |
| cdxgen | SBOM | `has_generic_code` | n/a | true |
| Grype (SBOM) | SBOM | after Syft | no | true |
| ScanCode | License/SBOM | `has_generic_code` | no | **false** |
| OpenSSF Scorecard | Supply chain | `has_generic_code` | yes | true |
| GuardDog | Supply / Malware | python/node/go | no | true |
| sbomqs | Supply chain | `has_generic_code` | no | true |
| pinact | Supply chain | `has_actions` | no | true |
| ratchet | Supply chain | `has_actions` | no | true |
| slsa-verifier | Supply chain | artifact inputs | no | true (skips if unset) |
| SECURITY-INSIGHTS check | Supply chain | `has_generic_code` | no | true |
| Bearer | Privacy | `has_generic_code` | yes | true |
| Presidio | Privacy | `has_generic_code` | no | true |
| Semgrep (privacy packs) | Privacy | `has_generic_code` | yes | true |
| Application Inspector | Privacy | `has_generic_code` | no | true |
| Spectral | API | `has_openapi` | no | true |
| vacuum | API | `has_openapi` | no | true |
| graphql-schema-linter | API | `has_graphql` | no | true |
| IBM OpenAPI Validator | API | `has_openapi` | no | true |
| ClamAV | Malware | `has_generic_code` | no | true |
| YARA | Malware | `has_generic_code` | no | true |
| capa | Malware | `has_binary` / paths | no | true |
| actionlint | Meta | `has_actions` | no | true |
| zizmor | Meta | `has_actions` | no | true |
| harden-runner | Meta | (self-test jobs) | n/a | true |

## Out of scope

DAST, commercial SCA/SAST, kube-bench (live cluster), OpenSSF Allstar (org app).
