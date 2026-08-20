# Results publishing

Scanners always emit:

1. **GitHub Actions artifacts** (JSON/SARIF/text per tool)
2. **Code Scanning alerts** when SARIF upload succeeds (`security-events: write`)

On **pull requests**, optionally post a **sticky PR comment**, **workflow annotations**, and/or **inline review comments** on diff lines via `pr-report-mode` (default `both`). This is separate from git publish.

Optionally persist a summary **into git** via `results-publish-mode` on `reusable-security-full` / `reusable-publish-results`.

## PR report (`pr-report-mode`)

| Mode | Behavior |
|------|----------|
| `none` | No PR feedback |
| `comment` | Upsert sticky comment (`<!-- scankit-pr-report -->`) with severity rollup + top findings |
| `annotations` | Emit file/line `::error` / `::warning` / `::notice` workflow commands (capped per level) |
| `inline` | Inline **PR review comments** on diff lines (Files tab threads) |
| `both` (default) | Sticky comment + workflow annotations |
| `all` | Sticky comment + workflow annotations + inline review comments |

Runs with `if: always()` after scanners so partial suites still report. Built from the same SARIF dedup as git publish (`findings-deduped.json`); secret-scanner raw artifacts stay excluded.

**Workflow annotations** are capped at 10 per severity level. **Inline review comments** use the Pull Request Review API; findings need SARIF `path:line` on the PR diff (max 25 per run). Prior inline comments tagged `<!-- scankit-inline -->` are replaced each run. Both use `continue-on-error` so permission or diff mismatches do not fail the suite.

The sticky comment is upserted via `<!-- scankit-pr-report -->` (`pull-requests: write`).

`pr-report-mode` is a no-op on `push` / `workflow_dispatch` / `schedule`. Independent of `results-publish-mode`.

## Git publish modes

| Mode | Behavior |
|------|----------|
| `none` | Default for PR/push templates — no git writes |
| `branch` | Commit under `security-results/<YYYY-MM-DD>/` and `security-results/latest/` on branch `security-results` (or `security-results/*` only) |
| `pull-request` | Same files on `chore/security-results`; open/update a PR into the default branch |

Publishing runs with `if: always()` so failed scanners still produce a summary. Aggregation also writes **`findings-deduped.json`**: unique findings keyed by rule + location + message, with a severity rollup and which tools reported each issue (SARIF only).

**Guards:** secret-scanner raw JSON/SARIF is never committed; `results-branch` cannot be `main`/`master`/default; `results-path` must stay under `security-results/`.

## Scheduled daily scans

Use [`templates/security-all-scheduled.yml`](../templates/security-all-scheduled.yml):

```yaml
on:
  schedule:
    - cron: "0 6 * * *"
  workflow_dispatch:

permissions:
  contents: write
  pull-requests: write
  security-events: write
  actions: read
  id-token: write

jobs:
  security:
    uses: OWNER/scankit/.github/workflows/reusable-security-full.yml@SHA
    with:
      results-publish-mode: pull-request
      scan-scope: full   # scheduled runs are not PRs; force a full-tree scan
```

Keep PR/push workflows on `results-publish-mode: none` so feature PRs are not filled with report commits. PR workflows default to `scan-scope: auto` (diff-only); scheduled templates should set `scan-scope: full`.

## Aggregation layout

```
security-results/
  2026-08-13/
    summary.md
    ecosystems.json
    <copied artifacts...>
  latest/
    (mirror of newest date folder)
```

Large antivirus databases are skipped. Prefer Code Scanning for alert triage; use git publish for audit snapshots and dashboards that read from the repo.
