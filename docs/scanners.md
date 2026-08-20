# Scanner inventory

Kitchen-sink OSS tools. Overlap is intentional. With `selection-mode: detected`, tools run only when the matching ecosystem flag is true (or always for polyglot scanners when `has_generic_code` is true).

With `scan-scope: auto` (default on the full suite), pull requests use **diff** mode: path-filterable tools scan changed files only; whole-program SAST (CodeQL, Gosec, Brakeman, SpotBugs) still runs when matching language files are in the diff (CodeQL uses the action’s incremental/diff-informed analysis). Scorecard stays skipped on PRs (repo-level). Other tools run only when the diff includes a relevant trigger (lockfile, Dockerfile, workflow, IaC). Push/`workflow_dispatch` use **full** mode. See [adoption.md](adoption.md#scan-scope-diff-vs-full).

### Diff-mode behavior (full suite)

| Behavior in `diff` | Tools |
|--------------------|-------|
| Path / file-list filter | Semgrep, Bandit, DevSkim, ShellCheck, detect-secrets, secretlint, Bearer, Spectral, ClamAV, YARA |
| Git range (PR-aware) | TruffleHog (PR base SHA), Gitleaks (history checkout), Dependency Review |
| Incremental / whole-program when language in diff | CodeQL (action incremental analysis; one matrix job per changed language), Gosec, Brakeman, SpotBugs (still needs `enable-code-build`) |
| Always skipped | Scorecard (repo-level policy, not PR-diff analysis) |
| Run if manifest/lockfile in diff (full tool) | OSV, Trivy FS, Grype FS, OWASP Dependency-Check, pip-audit, Retire.js, cargo-*, bundler-audit, php-security-checker, Syft/cdxgen/ScanCode/sbomqs, GuardDog |
| Run if Go manifest **or** `.go` in diff | govulncheck (source/call-graph mode) |
| Run if Dockerfile/compose in diff | Hadolint, Dockle, Trivy/Grype image, Dive, Cosign (when identity inputs are set) |
| Run if `.github/workflows/**` in diff | actionlint, zizmor, pinact, ratchet |
| Run if IaC files in diff (full tool) | Checkov, KICS, Trivy config, Terrascan, Conftest, kube-linter/kubeconform/kube-score/Kubescape, cfn-guard |
| Run if OpenAPI/GraphQL in diff | Spectral (path-filtered), vacuum, graphql-schema-linter, IBM OpenAPI Validator |
| Run if any file changed | Gitleaks/TruffleHog, privacy (Presidio / Semgrep privacy / Application Inspector; Bearer path-filters), capa (when binaries exist) |

Force a full PR scan with `scan-scope: full`. Category-only workflows default `scan-scope` to `full`; pass the resolve-scope outputs yourself if you call them standalone.

| Tool | Category | Ecosystem flag | SARIF | Default enable |
|------|----------|----------------|-------|----------------|
| OSV-Scanner | SCA | `has_generic_code` | yes | true |
| Trivy filesystem | SCA | `has_generic_code` | yes | true |
| Grype (dir / Anchore scan-action) | SCA | `has_generic_code` | yes | true |
| Dependency Review | SCA | `has_generic_code` (PR only; needs Dependency graph) | n/a | true |
| OWASP Dependency-Check | SCA | `has_generic_code` | no | true |
| pip-audit | SCA | `has_python` | no | true |
| govulncheck | SCA | `has_go` | no | true |
| Retire.js | SCA | `has_node` | no | true |
| cargo-audit | SCA | `has_rust` | no | true |
| cargo-deny | SCA | `has_rust` | no | true |
| bundler-audit | SCA | `has_ruby` | no | true |
| local-php-security-checker | SCA | `has_php` | no | true |
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
| Grype image (Anchore scan-action) | Container | `has_docker` / image | yes | true |
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
| Kubescape | IaC | `has_k8s` | no | true |
| cfn-guard | IaC | `has_cloudformation` | no | true |
| Anchore Syft (sbom-action) | SBOM | `has_generic_code` | n/a | true |
| Trivy SBOM | SBOM | `has_generic_code` | n/a | true |
| cdxgen | SBOM | `has_generic_code` | n/a | true |
| Anchore Grype (SBOM via scan-action) | SBOM | after Syft | yes | true |
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
| OWASP ZAP baseline | DAST (optional) | `enable-dast` + `dast-url` | no | false |

## Optional DAST

Enable on **staging URLs only** via `reusable-security-full.yml`:

```yaml
with:
  enable-dast: true
  dast-url: https://staging.example.com
```

See [`.github/workflows/reusable-dast.yml`](../.github/workflows/reusable-dast.yml). Never point at production.

## Out of scope

DAST on production, commercial SCA/SAST, kube-bench (live cluster), OpenSSF Allstar (org app). Optional DAST module covers staging baseline scans only.
