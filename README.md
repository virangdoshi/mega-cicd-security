# Scankit

[![CI Self-Test](https://github.com/virangdoshi/scankit/actions/workflows/ci-self-test.yml/badge.svg)](https://github.com/virangdoshi/scankit/actions/workflows/ci-self-test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/virangdoshi/scankit?include_prereleases)](https://github.com/virangdoshi/scankit/releases)

**Open-source security scanning for GitHub Actions — kitchen-sink coverage, ecosystem-aware, org-ready.**

Reusable workflows and copy-paste templates that run dozens of OSS scanners across SCA, SAST, secrets, containers, IaC, SBOM, supply chain, privacy/PII, static API security, malware, and Actions meta-lint. Overlapping tools are intentional. Irrelevant tools are skipped when your repo does not contain matching files. On pull requests, `scan-scope: auto` further limits scans to the changed-file diff.

[Scanner inventory](docs/scanners.md) · [Org adoption](docs/adoption.md) · [Upgrade 1.0 → 1.1](docs/upgrade-1.1.md) · [Results publishing](docs/results.md) · [Templates](templates/)

---

## Why this exists

Most teams bolt on one scanner at a time and end up with uneven coverage. This repository is a **shared security library**:

| Goal | How |
|------|-----|
| Broad coverage | Many OSS tools per category (duplicates welcome) |
| Low noise on empty ecosystems | Auto-detect languages/files; skip what does not apply |
| Diff-aware PRs | Default `scan-scope: auto` — scan changed files on PRs, full tree on push |
| Easy org rollout | Call once via `workflow_call`, or copy thin templates |
| Useful output | SARIF → Code Scanning, artifacts always, optional git PR/branch |
| Supply-chain hygiene | Third-party Actions pinned by commit SHA |

**Not included:** DAST (needs a live URL), commercial SaaS scanners, live-cluster CIS (kube-bench).

---

## Quick start

### 1. Publish this repo

Push to `YOUR_ORG/scankit` (public, or private with Actions access for callers). Tag releases (`v1.1.0`) when you can.

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
  contents: write
  pull-requests: write
  security-events: write
  actions: read
  id-token: write
  packages: read

concurrency:
  group: security-${{ github.ref }}
  cancel-in-progress: true

jobs:
  security:
    uses: YOUR_ORG/scankit/.github/workflows/reusable-security-full.yml@3cedcb4830bdaf09c99bb543ce59a747b3063885 # pin to commit SHA; bump when upgrading
    with:
      selection-mode: detected
      fail-on-severity: HIGH
      results-publish-mode: none
      # scan-scope: auto   # default — diff on pull_request, full on push/dispatch
      # enable-image-build / enable-code-build stay false on untrusted PRs
```

Prefer a **commit SHA** (or immutable release tag) instead of `@main` in production. Third-party Actions inside this library are already SHA-pinned. Caller permissions must match the full-suite ceiling (`contents: write` + `pull-requests: write` + `security-events: write`, even when publish mode is `none`).

**Or copy a template:**

```bash
cp templates/security-all.yml my-app/.github/workflows/security.yml
# Replace YOUR_ORG / OWNER and pin a SHA
```

### 3. Enable Code Scanning

App repo → **Settings → Code security → Code scanning**, so SARIF uploads show under the Security tab.

On each run: detect ecosystems → resolve scan scope (diff vs full) → parallel category scanners → SARIF + artifacts → optional git publish.

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
│  2. resolve scan scope      │
│  3. parallel category jobs  │
│  4. optional publish        │
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
    uses: YOUR_ORG/scankit/.github/workflows/reusable-secrets.yml@SHA
    with:
      selection-mode: detected
      fail-on-severity: HIGH
  sca:
    uses: YOUR_ORG/scankit/.github/workflows/reusable-sca.yml@SHA
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
| `scan-scope` | `auto` | `auto` = diff on `pull_request`, full on push/`workflow_dispatch`; or force `diff` / `full` |
| `fail-on-severity` | `HIGH` | `CRITICAL` \| `HIGH` \| `MEDIUM` \| `LOW` \| `NONE` |
| `results-publish-mode` | `none` | `none` \| `branch` \| `pull-request` |
| `pr-report-mode` | `both` | On `pull_request`: `none` \| `comment` \| `annotations` \| `both` (sticky PR summary + file/line annotations) |
| `image` / `dockerfile` | — | Container scans; builds Dockerfile when image empty |
| `enable-scancode` | `false` | Heavy license scan (opt-in) |
| `enable-<tool>` | `true` | Per-tool toggles on each category workflow |

`NONE` uploads findings but does not fail the job where soft-fail is supported. Overlap (e.g. Trivy + Grype + OSV) is expected — triage in Code Scanning, not in this library.

### Scan scope (diff vs full)

By default, **pull requests scan the diff**; **pushes and manual runs scan the whole checkout**.

| `scan-scope` | Behavior |
|--------------|----------|
| `auto` (default) | `diff` on `pull_request`; `full` otherwise |
| `diff` | Always use the PR/base…head changed-file set |
| `full` | Always scan the full tree |

In **diff** mode:

- Path-aware tools (Semgrep, Bandit, ShellCheck, detect-secrets, …) only scan matching changed files.
- Tools that cannot take a file list (CodeQL, Gosec, Scorecard, image scanners, …) are **skipped** unless the diff triggers them (e.g. lockfile → SCA, Dockerfile → container, `.github/workflows/**` → meta/pinact).
- SCA/SBOM still analyze manifests/lockfiles when those files change (not path-filtered line-by-line).

Force a full PR scan with `scan-scope: full`. More detail: [docs/adoption.md](docs/adoption.md#scan-scope-diff-vs-full).

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

Callers of `reusable-security-full` must grant the **workflow ceiling** (GitHub validates this at startup even when publish mode is `none`):

| `contents` | `pull-requests` | `security-events` | `actions` | `id-token` | `packages` |
|------------|-----------------|-------------------|-----------|------------|------------|
| **write** | **write** | **write** | read | write (Scorecard) | read |

Private library repos need org Actions access so app repos can `uses:` the workflows.

---

## Results

| Channel | When |
|---------|------|
| **GitHub Code Scanning** | SARIF-capable tools (always attempted) |
| **Actions artifacts** | Always |
| **PR comment + annotations** | On `pull_request` when `pr-report-mode` is `comment`, `annotations`, or `both` (default) |
| **Git `security-results/`** | When `results-publish-mode` is `branch` or `pull-request` |

```yaml
with:
  pr-report-mode: both                 # sticky PR comment + workflow annotations (PR events only)
  results-publish-mode: pull-request   # or branch | none — git snapshot, separate from PR comment
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
| Silent `startup_failure` | Caller permissions below full-suite ceiling | Grant `contents: write` + `pull-requests: write` + `security-events: write` |
| Too many jobs skipped | `detected` + no manifests, or `diff` + unrelated files | Use `all`, `scan-scope: full`, or change relevant files |
| Container jobs skipped | No Dockerfile / empty `image` / diff without Dockerfile | Pass `image`, add a Dockerfile, or use `scan-scope: full` |
| Cosign/SLSA skipped | Missing identity / artifact inputs | Set the inputs above |
| Publish did nothing | `none` or missing write perms | Set mode + `contents`/`pull-requests: write` |
| ClamAV slow | Freshclam + full tree | `enable-clamav: false` on malware workflow |

---

## Development

```bash
./scripts/detect-ecosystems.sh . /tmp/ecosystems.json
./scripts/resolve-scan-scope.sh auto pull_request <base_sha> <head_sha> /tmp/scope-out
./tests/run.sh
```

CI: [`.github/workflows/ci-self-test.yml`](.github/workflows/ci-self-test.yml) (unit tests + actionlint/zizmor + detect smoke).

### Reference docs

| Doc | Description |
|-----|-------------|
| [docs/scanners.md](docs/scanners.md) | Full tool inventory + diff-mode behavior |
| [docs/adoption.md](docs/adoption.md) | Org rollout, permissions ceiling, scan-scope |
| [docs/results.md](docs/results.md) | Publish modes & schedules |

---

## Security notes

- Prefer **SHA-pinned** `uses:` for this library and for third-party Actions (already pinned inside this repo).
- Workflow inputs are passed into shells via `env:` (not `${{ }}` interpolation inside `run:`) to avoid expression injection.
- Docker image builds and CodeQL/SpotBugs compiles are **off by default** (`enable-image-build` / `enable-code-build`) so PR pipelines do not execute untrusted build scripts.
- Results publish excludes secret-scanner artifacts and only allows `security-results` branch names.
- CI enforces Action pin hashes via [`scripts/check-action-pins.sh`](scripts/check-action-pins.sh) (run from `./tests/run.sh`).
- Dependabot updates those SHAs in a **single weekly grouped PR**.
- Grant callers the full permission ceiling required by `reusable-security-full` (see Quick start); publish mode still needs write when enabled.
- This suite finds issues — it does not replace threat modeling, review, or production monitoring.

---

## License

[MIT](LICENSE)
