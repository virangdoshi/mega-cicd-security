# Usage guide

This guide walks through installing Mega CI/CD Security in an organization, configuring scans, interpreting results, and operating day-to-day.

---

## Contents

1. [Prerequisites](#1-prerequisites)
2. [Install the library repository](#2-install-the-library-repository)
3. [Wire an application repository](#3-wire-an-application-repository)
4. [Category-only adoption](#4-category-only-adoption)
5. [Ecosystem detection](#5-ecosystem-detection)
6. [Tuning failures and noise](#6-tuning-failures-and-noise)
7. [Container and provenance inputs](#7-container-and-provenance-inputs)
8. [Publishing results to git](#8-publishing-results-to-git)
9. [Scheduled (daily) scans](#9-scheduled-daily-scans)
10. [Permissions matrix](#10-permissions-matrix)
11. [Pinning for production](#11-pinning-for-production)
12. [Troubleshooting](#12-troubleshooting)

---

## 1. Prerequisites

- GitHub Free/Team/Enterprise with Actions enabled
- Ability to create (or fork) `YOUR_ORG/mega-cicd-security`
- On each **application** repository:
  - Actions allowed to run
  - **Code scanning** enabled if you want SARIF in the Security tab  
    (Settings → Code security and analysis → Code scanning)
- For **private** library repos: grant the app repo access to use workflows from the library (org settings / Actions → General → Access)

---

## 2. Install the library repository

```bash
git clone <this-repo>
cd mega-cicd-security
# push to YOUR_ORG/mega-cicd-security
git remote add origin git@github.com:YOUR_ORG/mega-cicd-security.git
git push -u origin main
```

Optional but recommended: create a release tag (`v1.0.0`) and reference that tag or its commit SHA from callers.

---

## 3. Wire an application repository

### Option A — full suite (recommended)

Create `.github/workflows/security.yml`:

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
    uses: YOUR_ORG/mega-cicd-security/.github/workflows/reusable-security-full.yml@main
    with:
      selection-mode: detected
      fail-on-severity: HIGH
      results-publish-mode: none
```

What happens on each run:

1. Checkout of the **app** repo  
2. Ecosystem detection  
3. Parallel category workflows (only matching tools when `selection-mode: detected`)  
4. SARIF upload + artifacts  
5. Optional results publish (disabled above)

### Option B — copy a template

```bash
cp path/to/mega-cicd-security/templates/security-all.yml \
  my-app/.github/workflows/security.yml
# Edit OWNER → YOUR_ORG and pin a SHA
```

---

## 4. Category-only adoption

If you only want secrets + SCA:

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

Standalone category workflows default ecosystem flags to `"true"` so tools run even without the full orchestrator’s detect job. Prefer the full suite when you want accurate skipping.

Templates for every category live in [`templates/`](../templates/).

---

## 5. Ecosystem detection

Detection is implemented in [`scripts/detect-ecosystems.sh`](../scripts/detect-ecosystems.sh) and exposed as a composite action.

| Flag | Example signals |
|------|-----------------|
| `has_python` | `*.py`, `pyproject.toml`, `requirements*.txt` |
| `has_go` | `go.mod`, `*.go` |
| `has_java` | `pom.xml`, `build.gradle*`, `*.java` |
| `has_ruby` | `Gemfile`, `*.rb` |
| `has_node` | `package.json`, lockfiles |
| `has_rust` | `Cargo.toml` |
| `has_php` | `composer.json`, `*.php` |
| `has_dotnet` | `*.csproj`, `*.sln` |
| `has_docker` | `Dockerfile*`, compose files |
| `has_terraform` | `*.tf` |
| `has_k8s` | Helm charts, `apiVersion:` manifests |
| `has_cloudformation` | CFN / CDK cues |
| `has_openapi` | `openapi*` / `swagger*` / `asyncapi*` |
| `has_graphql` | `*.graphql`, `*.gql` |
| `has_shell` | `*.sh`, bash shebangs |
| `has_actions` | `.github/workflows/*` |
| `has_binary` | ELF/PE/Mach-O heuristics |
| `has_generic_code` | Non-empty source checkout |

**Modes**

- `selection-mode: detected` — run tool only if `enable-<tool>` and the ecosystem matches  
- `selection-mode: all` — run every enabled tool (jobs may still no-op if files are missing)

Local check:

```bash
./scripts/detect-ecosystems.sh /path/to/app /tmp/eco.json
cat /tmp/eco.json
```

---

## 6. Tuning failures and noise

### Severity gate

```yaml
with:
  fail-on-severity: HIGH   # or CRITICAL, MEDIUM, LOW, NONE
```

`NONE` uploads findings but does not fail the job (where the tool supports soft-fail).

### Disable individual tools

Category reusables accept `enable-<tool>` booleans (default `true`). Example on SCA:

```yaml
with:
  enable-owasp-dependency-check: false
  enable-retirejs: false
```

ScanCode (license) defaults to **off** even in the full suite (`enable-scancode: false`) because it is heavy.

### Overlap

Trivy + Grype + OSV may report the same CVE. That is expected. Deduplicate in your triage process or Code Scanning UI filters — not in this library (v1).

---

## 7. Container and provenance inputs

```yaml
with:
  image: ghcr.io/org/app:sha-abc123
  dockerfile: Dockerfile          # used when image is empty
  cosign-certificate-identity: "https://github.com/ORG/REPO/.github/workflows/build.yml@refs/heads/main"
  cosign-certificate-oidc-issuer: "https://token.actions.githubusercontent.com"
  slsa-artifact: ./dist/app.tar.gz
  slsa-source-uri: github.com/ORG/REPO
  conftest-policy-path: policy/   # Rego policies; Conftest skips if empty
```

Cosign verify and slsa-verifier **skip** when required inputs are empty.

---

## 8. Publishing results to git

```yaml
with:
  results-publish-mode: pull-request   # or branch | none
  results-branch: security-results     # for branch mode
```

Requires caller permissions:

```yaml
permissions:
  contents: write
  pull-requests: write
  security-events: write
```

Output layout:

```text
security-results/
  YYYY-MM-DD/
    summary.md
    ecosystems.json
    <copied sarif/json...>
  latest/          # mirror of newest date
```

Publishing uses `if: always()` so failed scanners still produce a summary.

---

## 9. Scheduled (daily) scans

Use [`templates/security-all-scheduled.yml`](../templates/security-all-scheduled.yml):

```yaml
on:
  schedule:
    - cron: "0 6 * * *"    # 06:00 UTC
  workflow_dispatch:

jobs:
  security:
    uses: YOUR_ORG/mega-cicd-security/.github/workflows/reusable-security-full.yml@SHA
    with:
      selection-mode: detected
      fail-on-severity: HIGH
      results-publish-mode: pull-request
```

Keep PR/push workflows on `results-publish-mode: none` so feature PRs are not cluttered with report commits.

---

## 10. Permissions matrix

| Capability | `contents` | `security-events` | `actions` | `id-token` | `pull-requests` | `packages` |
|------------|------------|-------------------|-----------|------------|-----------------|------------|
| Scan + SARIF | read | write | read | write (Scorecard) | read (dep review) | read (images) |
| Publish results PR/branch | **write** | write | read | write | **write** | read |

---

## 11. Pinning for production

```bash
# Resolve current main SHA
gh api repos/YOUR_ORG/mega-cicd-security/commits/main --jq .sha
```

```yaml
uses: YOUR_ORG/mega-cicd-security/.github/workflows/reusable-security-full.yml@11bd71901bbe5b1630ceea73d27597364c9af683
```

Third-party Actions inside this library are already SHA-pinned. Re-pin when you upgrade.

---

## 12. Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| SARIF missing in Security tab | Code Scanning disabled / private without GHAS | Enable Code Scanning; check job logs for upload errors |
| `uses:` cannot access workflow | Private library without access | Org Actions access to the library repo |
| Too many jobs skipped | `selection-mode: detected` + empty repo signals | Use `all`, or ensure manifests exist |
| Container jobs skipped | No Dockerfile / empty `image` | Pass `image` or add Dockerfile |
| Cosign/SLSA skipped | Missing identity / artifact inputs | Set the documented inputs |
| Publish did nothing | `results-publish-mode: none` or missing write perms | Set mode + `contents/pull-requests: write` |
| ClamAV slow | Freshclam + full tree scan | `enable-clamav: false` on malware workflow if needed |
| Scorecard soft findings | Default supply-chain fail severity `NONE` in full suite | Raise threshold in a custom caller if desired |

### Run library tests locally

```bash
./tests/run.sh
```

### Validate workflows in this repo

Push to the library repo and inspect the **CI Self-Test** workflow (detect smoke + meta linters).

---

## Next reading

- [Scanner inventory](scanners.md)
- [Adoption (org rollout)](adoption.md)
- [Results publishing](results.md)
- [Root README](../README.md)
