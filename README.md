# Mega CI/CD Security

[![CI Self-Test](https://github.com/virangdoshi/mega-cicd-security/actions/workflows/ci-self-test.yml/badge.svg)](https://github.com/virangdoshi/mega-cicd-security/actions/workflows/ci-self-test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/virangdoshi/mega-cicd-security?include_prereleases)](https://github.com/virangdoshi/mega-cicd-security/releases)

**Open-source security scanning for GitHub Actions — kitchen-sink coverage, ecosystem-aware, org-ready.**

Reusable workflows and copy-paste templates that run dozens of OSS scanners across SCA, SAST, secrets, containers, IaC, SBOM, supply chain, privacy/PII, static API security, malware, and Actions meta-lint. Overlapping tools are intentional. Irrelevant tools are skipped when your repo does not contain matching files.

[Scanner inventory](docs/scanners.md) · [Org adoption](docs/adoption.md) · [Results publishing](docs/results.md) · [Templates](templates/)

---

## Why this exists

Most teams bolt on one scanner at a time and end up with uneven coverage. This repository is a **shared security library**:

| Goal | How |
|------|-----|
| Broad coverage | Many OSS tools per category (duplicates welcome) |
| Low noise on empty ecosystems | Auto-detect languages/files; skip what does not apply |
| Easy org rollout | Call once via `workflow_call`, or copy thin templates |
| Useful output | SARIF → Code Scanning, artifacts always, optional git PR/branch |
| Supply-chain hygiene | Third-party Actions pinned by commit SHA |

**Not included:** DAST (needs a live URL), commercial SaaS scanners, live-cluster CIS (kube-bench).

---

## Quick start

### 1. Publish this repo

Push to `YOUR_ORG/mega-cicd-security` (public, or private with Actions access for callers). Tag releases (`v1.0.0`) when you can.

### 2. Wire an application repo

**Full suite** — create `.github/workflows/security.yml`:

```yaml
name: Security

on:
  pull_request:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  security-events: write
  actions: read
  id-token: write
  pull-requests: write
  packages: read

concurrency:
  group: security-${{ github.ref }}
  cancel-in-progress: true

jobs:
  security:
    uses: YOUR_ORG/mega-cicd-security/.github/workflows/reusable-security-full.yml@v1.0.0
    with:
      selection-mode: detected
      fail-on-severity: HIGH
      results-publish-mode: none
```

Prefer a **release tag** (e.g. `@v1.0.0`) or **commit SHA** instead of `@main` in production.

**Or copy a template:**

```bash
cp templates/security-all.yml my-app/.github/workflows/security.yml
# Replace YOUR_ORG / OWNER and pin a SHA
```

### 3. Enable Code Scanning

App repo → **Settings → Code security → Code scanning**, so SARIF uploads show under the Security tab.

On each run: detect ecosystems → parallel category scanners → SARIF + artifacts → optional git publish.

---

## Architecture

```text
┌─────────────────────────────┐
│  App repo starter workflow  │  templates/security-*.yml
└──────────────┬──────────────┘
               │ workflow_call
               ▼
┌─────────────────────────────┐
│   reusable-security-full    │
│  1. detect ecosystems       │
│  2. parallel category jobs  │
│  3. optional publish        │
└──────────────┬──────────────┘
               ▼
     Code Scanning + Artifacts
     (+ security-results/ PR or branch)
```

---

## Categories & entrypoints

| Category | Reusable workflow | Starter template |
|----------|-------------------|------------------|
| **Full suite** | [`reusable-security-full.yml`](.github/workflows/reusable-security-full.yml) | [`security-all.yml`](templates/security-all.yml) |
| **Scheduled + results PR** | same | [`security-all-scheduled.yml`](templates/security-all-scheduled.yml) |
| SCA | `reusable-sca.yml` | `security-sca.yml` |
| SAST (+ ShellCheck) | `reusable-sast.yml` | `security-sast.yml` |
| Secrets | `reusable-secrets.yml` | `security-secrets.yml` |
| Container | `reusable-container.yml` | `security-container.yml` |
| IaC / K8s | `reusable-iac.yml` | `security-iac.yml` |
| SBOM (+ optional ScanCode) | `reusable-sbom.yml` | `security-sbom.yml` |
| Supply chain | `reusable-supply-chain.yml` | `security-supply-chain.yml` |
| Privacy / PII | `reusable-privacy.yml` | `security-privacy.yml` |
| API (static) | `reusable-api.yml` | `security-api.yml` |
| Malware | `reusable-malware.yml` | `security-malware.yml` |
| Meta (Actions lint) | `reusable-meta.yml` | `security-meta.yml` |

Full tool list: [docs/scanners.md](docs/scanners.md).

### Category-only adoption

```yaml
jobs:
  secrets:
    uses: YOUR_ORG/mega-cicd-security/.github/workflows/reusable-secrets.yml@SHA
    with:
      selection-mode: detected
      fail-on-severity: HIGH
  sca:
    uses: YOUR_ORG/mega-cicd-security/.github/workflows/reusable-sca.yml@SHA
    with:
      selection-mode: detected
      fail-on-severity: HIGH
```

Standalone category workflows default ecosystem flags to `"true"`. Prefer the full suite when you want accurate skipping.

---

## Configuration

### Key inputs

| Input | Default | Meaning |
|-------|---------|---------|
| `selection-mode` | `detected` | `detected` = skip tools for missing ecosystems; `all` = force enabled tools |
| `fail-on-severity` | `HIGH` | `CRITICAL` \| `HIGH` \| `MEDIUM` \| `LOW` \| `NONE` |
| `results-publish-mode` | `none` | `none` \| `branch` \| `pull-request` |
| `image` / `dockerfile` | — | Container scans; builds Dockerfile when image empty |
| `enable-scancode` | `false` | Heavy license scan (opt-in) |
| `enable-<tool>` | `true` | Per-tool toggles on each category workflow |

`NONE` uploads findings but does not fail the job where soft-fail is supported. Overlap (e.g. Trivy + Grype + OSV) is expected — triage in Code Scanning, not in this library.

### Ecosystem detection

Implemented in [`scripts/detect-ecosystems.sh`](scripts/detect-ecosystems.sh) (also a composite action).

| Flag | Example signals |
|------|-----------------|
| `has_python` | `*.py`, `pyproject.toml`, `requirements*.txt` |
| `has_go` | `go.mod`, `*.go` |
| `has_java` | `pom.xml`, `build.gradle*`, `*.java` |
| `has_ruby` | `Gemfile`, `*.rb` |
| `has_node` | `package.json`, lockfiles |
| `has_rust` / `has_php` / `has_dotnet` | `Cargo.toml` / `composer.json` / `*.csproj` |
| `has_docker` | `Dockerfile*`, compose files |
| `has_terraform` / `has_k8s` / `has_cloudformation` | `*.tf` / Helm+manifests / CFN·CDK |
| `has_openapi` / `has_graphql` | `openapi*`·`swagger*` / `*.graphql` |
| `has_shell` / `has_actions` / `has_binary` | `*.sh` / `.github/workflows` / ELF·PE·Mach-O |
| `has_generic_code` | Non-empty source checkout |

```bash
./scripts/detect-ecosystems.sh /path/to/app /tmp/eco.json
```

### Container & provenance

```yaml
with:
  image: ghcr.io/org/app:sha-abc123
  dockerfile: Dockerfile
  cosign-certificate-identity: "https://github.com/ORG/REPO/.github/workflows/build.yml@refs/heads/main"
  cosign-certificate-oidc-issuer: "https://token.actions.githubusercontent.com"
  slsa-artifact: ./dist/app.tar.gz
  slsa-source-uri: github.com/ORG/REPO
  conftest-policy-path: policy/
```

Cosign verify and slsa-verifier **skip** when required inputs are empty.

### Permissions

| Capability | `contents` | `security-events` | `actions` | `id-token` | `pull-requests` | `packages` |
|------------|------------|-------------------|-----------|------------|-----------------|------------|
| Scan + SARIF | read | write | read | write (Scorecard) | read (dep review) | read (images) |
| Publish results PR/branch | **write** | write | read | write | **write** | read |

Private library repos need org Actions access so app repos can `uses:` the workflows.

---

## Results

| Channel | When |
|---------|------|
| **GitHub Code Scanning** | SARIF-capable tools (always attempted) |
| **Actions artifacts** | Always |
| **Git `security-results/`** | When `results-publish-mode` is `branch` or `pull-request` |

```yaml
with:
  results-publish-mode: pull-request   # or branch | none
  results-branch: security-results
```

```text
security-results/
  YYYY-MM-DD/
    summary.md
    ecosystems.json
    …
  latest/
```

**Daily audits:** [`templates/security-all-scheduled.yml`](templates/security-all-scheduled.yml) (`cron` + `pull-request`). Keep PR/push workflows on `none` so feature PRs stay clean.

More detail: [docs/results.md](docs/results.md).

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| SARIF missing in Security tab | Code Scanning off / private without GHAS | Enable Code Scanning; check upload logs |
| `uses:` cannot access workflow | Private library without access | Grant org Actions access to the library |
| Too many jobs skipped | `detected` + no manifests | Use `all`, or add language/IaC files |
| Container jobs skipped | No Dockerfile / empty `image` | Pass `image` or add a Dockerfile |
| Cosign/SLSA skipped | Missing identity / artifact inputs | Set the inputs above |
| Publish did nothing | `none` or missing write perms | Set mode + `contents`/`pull-requests: write` |
| ClamAV slow | Freshclam + full tree | `enable-clamav: false` on malware workflow |

---

## Development

```bash
./scripts/detect-ecosystems.sh . /tmp/ecosystems.json
./tests/run.sh
```

CI: [`.github/workflows/ci-self-test.yml`](.github/workflows/ci-self-test.yml) (unit tests + actionlint/zizmor + detect smoke).

### Reference docs

| Doc | Description |
|-----|-------------|
| [docs/scanners.md](docs/scanners.md) | Full tool inventory |
| [docs/adoption.md](docs/adoption.md) | Org rollout notes |
| [docs/results.md](docs/results.md) | Publish modes & schedules |

---

## Security notes

- Prefer **SHA-pinned** `uses:` for this library and for third-party Actions (already pinned inside this repo).
- CI enforces pin hashes via [`scripts/check-action-pins.sh`](scripts/check-action-pins.sh) (run from `./tests/run.sh`).
- Dependabot updates those SHAs in a **single weekly grouped PR**.
- Grant callers least privilege; only add write permissions when publishing results.
- This suite finds issues — it does not replace threat modeling, review, or production monitoring.

---

## License

[MIT](LICENSE)
