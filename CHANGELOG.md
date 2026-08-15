# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Security

- Add SECURITY.md (vulnerability reporting + scope)
- Pin pip installs with `--require-hashes` (`.github/pinned/*.txt`)
- Verify release binary SHA256 (dockle, dive, slsa-verifier, php-security-checker)
- Pin go tools to commit SHA / release tags (no `@latest`)
- Move `security-events: write` to job-level; keep workflow defaults read-only
- Bump test fixture `requests` to 2.33.0 (clears Scorecard Vulnerabilities false positive)
- Eliminate `${{ inputs.* }}` interpolation inside `run:` shells (pass via `env:`)
- Default-disable Docker builds and CodeQL/SpotBugs compiles on untrusted code (`enable-image-build` / `enable-code-build`)
- Exclude secret-scanner artifacts from results aggregation/publish; allowlist `security-results*` publish branches
- Full suite requests read-only contents by default; publish job elevates only when publishing
- Pin installer scripts, npm/pip/go tools, Semgrep image tags, and release binaries (no `main`/`latest` for scanners)
- Scorecard `publish_results` defaults to false
- Harden `detect-ecosystems.sh` filename handling (`find -print0` / `xargs -0`)

### Changed

- Dependabot now groups GitHub Actions updates into a **single weekly PR** (was one PR per action)
- Enforce **commit-SHA pins** for all remote Actions (`scripts/check-action-pins.sh`); templates pin to a SHA instead of `@main`
- Scan-only templates drop `pull-requests: write`

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
