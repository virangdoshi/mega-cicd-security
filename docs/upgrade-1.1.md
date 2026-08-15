# Upgrade from 1.0 → 1.1

Bump your caller pin to the [v1.1.0](https://github.com/virangdoshi/scankit/releases/tag/v1.1.0) commit SHA (templates and README in this repo already use it). Prefer a **commit SHA** over `@main`.

## What changed

| Area | 1.0 | 1.1 |
|------|-----|-----|
| PR scan scope | Full tree | `scan-scope: auto` — diff on `pull_request`, full on push/dispatch |
| PR feedback | Artifacts + Code Scanning only | Optional sticky comment + file annotations (`pr-report-mode`, default `both`) |
| Cross-repo pins | Some jobs looked in the **caller** workspace for `.github/pinned/*` | Resolved via `scankit-root` inside the library checkout |
| Permissions | Same ceiling | Still required: `contents: write`, `pull-requests: write`, `security-events: write` (even when `results-publish-mode: none`) |

## Required pin bump

```yaml
# before (example 1.0 pin)
uses: YOUR_ORG/scankit/.github/workflows/reusable-security-full.yml@<old-sha>

# after — use the SHA printed on the v1.1.0 release page
uses: YOUR_ORG/scankit/.github/workflows/reusable-security-full.yml@<v1.1.0-sha>
```

Copy-paste starters live under [`templates/`](../templates/).

## New optional inputs

```yaml
with:
  scan-scope: auto              # default; use `full` for scheduled / audit runs
  pr-report-mode: both          # default; sticky PR comment + annotations
  # quieter PRs:
  # pr-report-mode: comment     # summary only
  # pr-report-mode: none        # Code Scanning / artifacts only
```

`pr-report-mode` only applies on `pull_request` events and does not require `results-publish-mode`.

## Keeping the pin current

Dependabot’s `github-actions` ecosystem updates SHA-pinned third-party Actions **and** reusable workflow pins when the ref is already a commit SHA. In the **application** repo:

```yaml
# .github/dependabot.yml
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

Renovate equivalent: enable the `github-actions` manager so `uses: org/scankit/...@sha` receives update PRs when you publish new scankit releases.

## Expectation check

Intentional-vuln corpora (and many real apps with HIGH debt) will fail jobs when `fail-on-severity: HIGH`. That is the gate working. For soak / CI green on a known-bad tree, use `fail-on-severity: NONE` and triage via Code Scanning or the PR report.
