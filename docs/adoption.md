# Adoption guide

Step-by-step setup lives in the **[README](../README.md)**. This page covers organization rollout choices only.

Upgrading from 1.0? See **[Upgrade 1.0 → 1.1](upgrade-1.1.md)**.

## Choose a consumption model

### Reusable workflows (recommended for orgs)

Point app repos at this library:

```yaml
jobs:
  security:
    uses: OWNER/scankit/.github/workflows/reusable-security-full.yml@3cedcb4830bdaf09c99bb543ce59a747b3063885 # pin to commit SHA; bump when upgrading
    with:
      selection-mode: detected
      fail-on-severity: HIGH
      results-publish-mode: none
      # pr-report-mode: both  # sticky PR comment + annotations (default)
      # scan-scope: auto  # default — diff on PRs, full on push/dispatch
      # enable-image-build / enable-code-build only on trusted refs
```

Prefer a **commit SHA** (not `@main`) for supply-chain hygiene. Caller workflows must grant the full permission ceiling below even when `results-publish-mode: none` (GitHub validates job scopes at startup). Category-only entrypoints live under `.github/workflows/reusable-*.yml`.

### Copy-paste templates

Copy files from [`templates/`](../templates/) into the app’s `.github/workflows/`, replace `OWNER/scankit`, and pin a commit SHA.

## Required GitHub settings

1. **Actions** enabled for the app repo.
2. **Code Scanning** enabled so SARIF uploads show under the Security tab (public repos: free; private: GitHub Advanced Security entitlement).
3. **Dependency graph** so SCA **Dependency Review** can compare PR dependency diffs (public: free; private: GHAS). The job is PR-only; disable with `enable-dependency-review: false` on `reusable-sca`.
4. For **private** reusable workflow libraries, grant caller access (see below).

## Private library access (org settings)

When `scankit` is **private**, application repositories cannot call `uses: org/scankit/...` until access is granted:

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
| Scan only / publish | `contents: write`, `pull-requests: write`, `security-events: write`, `actions: read`, `id-token: write` (Scorecard), `packages: read` |

`reusable-security-full` declares `contents: write` + `pull-requests: write` at the workflow level (for the optional publish job). The caller must grant at least that ceiling or GitHub fails the run at **startup** with no job logs. Nested reusable workflows declare their own `permissions:` blocks within that ceiling.

## Selection modes

- `detected` (default) — skip tools whose ecosystems are absent.
- `all` — run every enabled tool even if files are missing (jobs may no-op internally).

Disable a single tool with the corresponding `enable-<tool>: false` input on the category reusable.

## Scan scope (diff vs full)

`reusable-security-full` input `scan-scope`:

| Value | Behavior |
|-------|----------|
| `auto` (default) | `diff` on `pull_request`, `full` on push / `workflow_dispatch` |
| `diff` | Changed files; path-filter where possible; whole-program SAST if that language changed |
| `full` | Scan the whole checkout |

In **diff** mode:

- Tools that accept path lists (Semgrep, Bandit, detect-secrets, Bearer, Spectral, …) scan only matching changed files.
- Whole-program SAST **does** run when matching language files are in the diff: CodeQL (GitHub incremental/diff-informed analysis), Gosec, Brakeman, SpotBugs (still requires `enable-code-build`).
- Scorecard is **always skipped** on diffs (repo-level OpenSSF checks; official cadence is default-branch push + schedule).
- Other full-tree tools run only when the diff gives them a reason (lockfile → SCA/SBOM, Dockerfile → container, `.github/workflows/**` → meta/pinact, `.tf`/Helm/YAML → IaC).
- SCA/SBOM still run against the repo/manifests when a relevant lockfile/manifest is in the diff (not path-filtered). govulncheck also runs when `.go` source changes.

**Category-only** reusable workflows (`reusable-sast.yml`, etc.) default `scan-scope` to `full`. Diff gating is wired through `reusable-security-full` (resolve job + artifact). Prefer the full suite for PR diff behavior, or pass `scan-scope` / changed-file inputs yourself when calling categories standalone.

Callers do not vendor `.github/pinned/` or `scripts/` — those resolve from the scankit action checkout via `scankit-root`.

## Org placement

Publish under your org (for example `your-org/scankit`), tag releases (`v1.1.0`), and reference those tags or commit SHAs from application repositories. Enable Dependabot (included in this repo) to keep Action SHAs current.

## Keeping scankit pins fresh (app repos)

In each **caller** repository, Dependabot (or Renovate) can open PRs when you bump scankit releases, as long as `uses:` already pins a commit SHA:

```yaml
# .github/dependabot.yml (application repo)
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: weekly
    open-pull-requests-limit: 1
    groups:
      github-actions:
        patterns:
          - "*"
```

After each scankit release, either merge the Dependabot PR or manually replace the SHA in your workflow with the release commit from the [Releases](https://github.com/virangdoshi/scankit/releases) page.

## PR report noise

Default `pr-report-mode: both` posts a sticky summary and file/line annotations. For quieter PRs set `pr-report-mode: comment` (summary only) or `none`. Annotations are most useful when `fail-on-severity` is high and you want Checks/Files highlights; intentional-vuln soak repos often use `fail-on-severity: NONE` plus `pr-report-mode: comment`.
