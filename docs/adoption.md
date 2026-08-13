# Adoption guide

Step-by-step setup lives in the **[README](../README.md)**. This page covers organization rollout choices only.

## Choose a consumption model

### Reusable workflows (recommended for orgs)

Point app repos at this library:

```yaml
jobs:
  security:
    uses: OWNER/mega-cicd-security/.github/workflows/reusable-security-full.yml@5c116447f13eea8bb8c9ee254464ce0f981eda48 # pin to commit SHA; bump when upgrading
    with:
      selection-mode: detected
      fail-on-severity: HIGH
      results-publish-mode: none
```

Prefer a **commit SHA** (not `@main`) for supply-chain hygiene. Category-only entrypoints live under `.github/workflows/reusable-*.yml`.

### Copy-paste templates

Copy files from [`templates/`](../templates/) into the app’s `.github/workflows/`, replace `OWNER/mega-cicd-security`, and pin a commit SHA.

## Required GitHub settings

1. **Actions** enabled for the app repo.
2. **Code Scanning** enabled so SARIF uploads show under the Security tab (public repos: free; private: GitHub Advanced Security entitlement).
3. For **private** reusable workflow libraries, grant caller access (see below).

## Private library access (org settings)

When `mega-cicd-security` is **private**, application repositories cannot call `uses: org/mega-cicd-security/...` until access is granted:

1. Open the **library** repo → **Settings → Actions → General**.
2. Under **Access**, choose:
   - **Accessible from repositories in the `ORG` organization**, or
   - **Accessible from repositories in the enterprise** (Enterprise only).
3. Optionally restrict to selected repositories.
4. Ensure the calling workflow’s actor (default `GITHUB_TOKEN`) can read the library repo. Same-org private access via the setting above is usually enough; cross-org callers need an explicit grant or a public library.

Forks of private libraries do **not** inherit reusable-workflow access — point `uses:` at the canonical org repo.

## Permissions

| Mode | Caller `permissions` |
|------|----------------------|
| Scan only | `contents: read`, `security-events: write`, `actions: read`, `id-token: write` (Scorecard) |
| Publish PR/branch | also `contents: write`, `pull-requests: write` |

Nested reusable workflows declare their own `permissions:` blocks; the caller must grant at least those scopes.

## Selection modes

- `detected` (default) — skip tools whose ecosystems are absent.
- `all` — run every enabled tool even if files are missing (jobs may no-op internally).

Disable a single tool with the corresponding `enable-<tool>: false` input on the category reusable.

## Org placement

Publish under your org (for example `your-org/mega-cicd-security`), tag releases (`v1.0.0`), and reference those tags or commit SHAs from application repositories. Enable Dependabot (included in this repo) to keep Action SHAs current.
