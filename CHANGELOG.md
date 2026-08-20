# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Inline PR review comments** (`pr-report-mode: inline | all`): post findings as review threads on diff lines via Pull Request Review API; replaces prior `<!-- scankit-inline -->` comments each run (cap 25).

## [1.2.0] — 2026-08-19

### Added

- **Scan profiles** (`profile: minimal | standard | audit | soak`) via `resolve-settings` action and [`scripts/resolve-profile.sh`](scripts/resolve-profile.sh)
- **Scan-only workflow** [`reusable-security-scan.yml`](.github/workflows/reusable-security-scan.yml) — read-only permission ceiling (no publish/PR comment jobs)
- **`.scankit.yml` config** — [`scripts/load-scankit-config.sh`](scripts/load-scankit-config.sh), [`load-config`](.github/actions/load-config/) / [`resolve-settings`](.github/actions/resolve-settings/) actions, [`docs/config.md`](docs/config.md)
- **Optional DAST** — [`reusable-dast.yml`](.github/workflows/reusable-dast.yml) (OWASP ZAP baseline, staging URL only)
- **Notifications** — [`reusable-notify.yml`](.github/workflows/reusable-notify.yml) + `enable-notifications` / `notification-webhook` inputs
- **PR triage UX** — category grouping and multi-tool overlap note in [`scripts/pr-report.sh`](scripts/pr-report.sh); `by_category` in dedup JSON
- New templates: `security-minimal`, `security-audit`, `security-soak`, `security-scan-only`, `org-security-policy`, `scankit.yml.example`
- Demo app: [virangdoshi/scankit-demo](https://github.com/virangdoshi/scankit-demo) (external repo — intentional findings for soak mode)
- Docs: [`quickstart.md`](docs/quickstart.md), [`performance.md`](docs/performance.md), [`vs-alternatives.md`](docs/vs-alternatives.md), [`compliance.md`](docs/compliance.md), [`triage.md`](docs/triage.md), [`marketplace.md`](docs/marketplace.md), [`openssf-badge.md`](docs/openssf-badge.md), [`upgrade-1.2.md`](docs/upgrade-1.2.md), [`renovate-preset.json`](docs/renovate-preset.json)
- Scripts: [`run-local.sh`](scripts/run-local.sh), [`trend-summary.sh`](scripts/trend-summary.sh), [`export-defectdojo.sh`](scripts/export-defectdojo.sh), [`bump-template-pins.sh`](scripts/bump-template-pins.sh)
- Community: [`CONTRIBUTING.md`](CONTRIBUTING.md), [`ROADMAP.md`](ROADMAP.md), GitHub issue templates

## [1.1.1] — 2026-08-19

### Fixed

- SCA **Dependency Review**: map scankit `fail-on-severity` (`CRITICAL`/`HIGH`/`MEDIUM`/`LOW`/`NONE`) onto the action’s `critical`/`high`/`moderate`/`low` scale (default `HIGH` was invalid and failed the job). `NONE` uses `warn-only`. Checkout + JSON artifacts. PR/`pull_request_target` only.

### Changed

- Docs: architecture and category table include PR report; maintainer pin regeneration (`pip-compile --allow-unsafe`)
- Diff mode: run whole-program SAST when matching language files change (CodeQL incremental analysis, Gosec, Brakeman, SpotBugs) instead of hard-skipping; govulncheck also runs on `.go` diffs. Scorecard remains PR-skipped (repo-level).
- Extract `scripts/prepare-scan-paths.sh` from the composite action so path filtering is unit-tested

### Added

- First-party [`.github/workflows/dependency-review.yml`](.github/workflows/dependency-review.yml): GitHub Dependency Review on this repo’s pull requests (`fail-on-severity: moderate`, PR comment)
- Broader `./tests/run.sh` coverage: remaining detect-ecosystem fixtures, scan-scope flags (IaC/Docker/workflows/API/Java/Ruby), `verify-sha256`, `prepare-scan-paths`, `scankit-root` path math, all starter templates, actionlint on `templates/`

## [1.1.0] — 2026-08-15

### Added

- **Diff-scoped scanning** (`scan-scope: auto|diff|full`, default `auto`): PRs scan changed files; push/`workflow_dispatch` scan the full tree. Path-filterable tools use the diff; tools that cannot path-scope are skipped unless the diff triggers them (lockfile, Dockerfile, workflows, etc.).
- Composite actions / scripts: `resolve-scan-scope`, `prepare-scan-paths`, `scankit-root`, `pr-report`, `scripts/resolve-scan-scope.sh`, `scripts/filter-changed-files.sh`, `scripts/pr-report.sh`
- **PR report** (`pr-report-mode: none|comment|annotations|both`, default `both`): on `pull_request`, sticky summary comment + workflow file/line annotations from deduped SARIF findings (independent of `results-publish-mode`)
- Anchore SBOM + Grype pipeline: `anchore/sbom-action` (Syft SPDX/CycloneDX) and `anchore/scan-action` Grype SBOM scan with SARIF → Code Scanning (`sbom-anchore-syft` / `sbom-anchore-grype`)
- Upgrade guide: [`docs/upgrade-1.1.md`](docs/upgrade-1.1.md)

### Fixed

- Cross-repo callers: resolve `.github/pinned/*` and `scripts/verify-sha256.sh` via new `scankit-root` composite action (`github.action_path`) instead of `GITHUB_WORKSPACE` (which is the caller checkout)
- TruffleHog: replace broken `--only-verified=false` with `--results=verified,unknown`; honor `fail-on-severity: NONE` for Gitleaks/TruffleHog via `continue-on-error`
- Regenerate `flare-capa` / `presidio-analyzer` hash pins with `pip-compile --allow-unsafe` (pip/setuptools); bump ratchet job to Go 1.24
- Semgrep container jobs: set `shell: bash` so `mapfile` / `[[` work (container default is `sh`)
- PR report annotations: strip `./` prefix correctly (`lstrip` bug); escape `,`/`:` in titles; accurate cap/omit counts
- Restore `reusable-security-full` workflow-level permission ceiling (`contents`/`pull-requests`/`security-events: write`) so nested job scopes are valid for cross-repo callers (avoids silent `startup_failure`)

### Security

- Override transitive `lodash` to `4.18.1` in `.github/pinned/npm-api` (GHSA-f23m-r3pf-42rh / GHSA-r5fr-rjxr-66jc)
- Replace remaining `curl|sh` / unpinned npm/cargo/rustup installs with SHA256-verified release binaries, `npm ci` lockfile (`.github/pinned/npm-api`), and hashed ScanCode requirements (Scorecard Pinned-Dependencies)
- Bump Trivy installs to v0.74.0 and KICS to v2.1.20 (release assets + checksums)
- Digest-pin test fixture `alpine:3.19`; pin `tests/run.sh` actionlint download
- Add SECURITY.md (vulnerability reporting + scope)
- Pin pip installs with `--require-hashes` (`.github/pinned/*.txt`)
- Verify release binary SHA256 (dockle, dive, slsa-verifier, php-security-checker, trivy, bearer, syft, …)
- Pin go tools to commit SHA / release tags (no `@latest`)
- Eliminate `${{ inputs.* }}` interpolation inside `run:` shells (pass via `env:`)
- Default-disable Docker builds and CodeQL/SpotBugs compiles on untrusted code (`enable-image-build` / `enable-code-build`)
- Exclude secret-scanner artifacts from results aggregation/publish; allowlist `security-results*` publish branches
- Pin installer scripts, npm/pip/go tools, Semgrep image tags, and release binaries (no `main`/`latest` for scanners)
- Scorecard `publish_results` defaults to false
- Harden `detect-ecosystems.sh` filename handling (`find -print0` / `xargs -0`)

### Changed

- Dependabot now groups GitHub Actions updates into a **single weekly PR** (was one PR per action)
- Enforce **commit-SHA pins** for all remote Actions (`scripts/check-action-pins.sh`); templates pin to a SHA instead of `@main`
- Full-suite callers must grant `contents: write` + `pull-requests: write` + `security-events: write` (ceiling), even when `results-publish-mode: none`
- Document `scan-scope` in README, adoption, scanners, and templates
- Keep `pr-report-mode` default `both` (sticky comment + annotations); use `comment` or `none` for quieter PRs — see upgrade guide

## [1.0.0] — 2026-08-13

### Added

- Reusable workflows for SCA, SAST, secrets, container, IaC, SBOM, supply chain, privacy/PII, static API, malware, and Actions meta-lint
- `reusable-security-full` orchestrator with ecosystem detection and optional results publish (`none` | `branch` | `pull-request`)
- Language SCA: cargo-audit, cargo-deny, bundler-audit, local-php-security-checker
- IaC: Kubescape, cfn-guard (in addition to Checkov/KICS/Terrascan/kube-*)
- Cross-tool SARIF dedup rollup in `scripts/aggregate-results.sh` (`findings-deduped.json`)
- Starter templates under `templates/`
- Local/CI test suite (`./tests/run.sh`) including actionlint
- Dependabot for GitHub Actions
- CODEOWNERS and docs for private-library org access

### Fixed

- Ecosystem detection glob quoting bug
- Meta/zizmor CI failure when Code Scanning SARIF upload is unavailable
