# Adoption guide

For step-by-step setup, see the **[Usage guide](usage.md)**. This page focuses on organization rollout choices.

## Choose a consumption model

### Reusable workflows (recommended for orgs)

Point app repos at this library:

```yaml
jobs:
  security:
    uses: OWNER/mega-cicd-security/.github/workflows/reusable-security-full.yml@<SHA>
    with:
      selection-mode: detected
      fail-on-severity: HIGH
      results-publish-mode: none
```

Pin `@<SHA>` (not `@main`) for supply-chain hygiene. Category-only entrypoints live under `.github/workflows/reusable-*.yml`.

### Copy-paste templates

Copy files from [`templates/`](../templates/) into the app’s `.github/workflows/`, replace `OWNER/mega-cicd-security`, and pin a SHA.

## Required GitHub settings

1. **Actions** enabled for the app repo.
2. **Code Scanning** enabled so SARIF uploads show under the Security tab (public repos: free; private: per GitHub Advanced Security entitlement).
3. For private reusable workflow libraries, grant the app repo access to the library repository.

## Permissions

| Mode | Caller `permissions` |
|------|----------------------|
| Scan only | `contents: read`, `security-events: write`, `actions: read`, `id-token: write` (Scorecard) |
| Publish PR/branch | also `contents: write`, `pull-requests: write` |

## Selection modes

- `detected` (default) — skip tools whose ecosystems are absent.
- `all` — run every enabled tool even if files are missing (jobs may no-op internally).

Disable a single tool with the corresponding `enable-<tool>: false` input on the category reusable (pass through from your caller as needed).

## Org placement

Publish this repository under your org (for example `your-org/mega-cicd-security`), tag releases (`v1`, `v1.2.3`), and reference those tags or commit SHAs from application repositories.
