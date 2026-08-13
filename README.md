# Mega CI/CD Security

**Open-source security scanning for GitHub Actions — kitchen-sink coverage, ecosystem-aware, org-ready.**

Reusable workflows and copy-paste templates that run dozens of OSS scanners across SCA, SAST, secrets, containers, IaC, SBOM, supply chain, privacy/PII, static API security, malware, and Actions meta-lint. Overlapping tools are intentional. Irrelevant tools are skipped when your repo does not contain matching files.

[Usage guide](docs/usage.md) · [Scanner inventory](docs/scanners.md) · [Adoption](docs/adoption.md) · [Results publishing](docs/results.md) · [Templates](templates/)

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

## Quick start (2 minutes)

### 1. Publish this repo

Push to `YOUR_ORG/mega-cicd-security` (public or private with Actions access for callers).

### 2. Add a workflow to an application repo

```yaml
# .github/workflows/security.yml
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

jobs:
  security:
    uses: YOUR_ORG/mega-cicd-security/.github/workflows/reusable-security-full.yml@main
    with:
      selection-mode: detected
      fail-on-severity: HIGH
      results-publish-mode: none
```

Prefer pinning a **commit SHA** instead of `@main` in production.

### 3. Enable Code Scanning

In the app repo: **Settings → Code security → Code scanning** so SARIF uploads appear under the Security tab.

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
               │
     ┌─────────┼─────────┬──────────┬─────────┐
     ▼         ▼         ▼          ▼         ▼
   SCA/SAST  Secrets  Container   IaC/SBOM  Supply/…
     │         │         │          │         │
     └─────────┴─────────┴──────────┴─────────┘
               │
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

---

## Key inputs

| Input | Default | Meaning |
|-------|---------|---------|
| `selection-mode` | `detected` | `detected` = skip tools for missing ecosystems; `all` = force enabled tools |
| `fail-on-severity` | `HIGH` | `CRITICAL` \| `HIGH` \| `MEDIUM` \| `LOW` \| `NONE` |
| `results-publish-mode` | `none` | `none` \| `branch` \| `pull-request` |
| `image` / `dockerfile` | — | Container scans; builds Dockerfile when image empty |
| `enable-scancode` | `false` | Heavy license scan (opt-in) |
| `enable-<tool>` | `true` | Per-tool toggles on each category workflow |

Ecosystem detection flags (examples): `has_python`, `has_go`, `has_docker`, `has_openapi`, `has_shell`, `has_actions`, …

---

## Results

| Channel | When |
|---------|------|
| **GitHub Code Scanning** | SARIF-capable tools (always attempted) |
| **Actions artifacts** | Always |
| **Git `security-results/`** | When `results-publish-mode` is `branch` or `pull-request` |

Daily audit pattern: use [`templates/security-all-scheduled.yml`](templates/security-all-scheduled.yml) (`cron` + `results-publish-mode: pull-request`). Keep PR builds on `none` so feature PRs stay clean.

Details: [docs/results.md](docs/results.md).

---

## Two ways to adopt

**A. Reusable workflows (orgs)** — one library repo; apps call `uses: org/mega-cicd-security/...@sha`.

**B. Templates** — copy [`templates/`](templates/) into each app; still calls the library (or fork and vendor).

See [docs/usage.md](docs/usage.md) and [docs/adoption.md](docs/adoption.md).

---

## Development

```bash
# Ecosystem detection smoke test
./scripts/detect-ecosystems.sh . /tmp/ecosystems.json

# Unit / integration tests
./tests/run.sh
```

CI self-test: [`.github/workflows/ci-self-test.yml`](.github/workflows/ci-self-test.yml) (unit tests + actionlint/zizmor + detect smoke).

---

## Documentation

| Doc | Description |
|-----|-------------|
| [docs/usage.md](docs/usage.md) | End-to-end usage guide |
| [docs/scanners.md](docs/scanners.md) | Full tool inventory |
| [docs/adoption.md](docs/adoption.md) | Org rollout & permissions |
| [docs/results.md](docs/results.md) | Artifacts, Code Scanning, PR/branch publish |

---

## Security notes

- Prefer **SHA-pinned** `uses:` for this library and for third-party Actions.
- Grant callers least privilege; only add `contents: write` / `pull-requests: write` when publishing results.
- This suite finds issues — it does not replace threat modeling, review, or production monitoring.

---

## License

[MIT](LICENSE)
