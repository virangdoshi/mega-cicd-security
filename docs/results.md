# Results publishing

Scanners always emit:

1. **GitHub Actions artifacts** (JSON/SARIF/text per tool)
2. **Code Scanning alerts** when SARIF upload succeeds (`security-events: write`)

Optionally persist a summary **into git** via `results-publish-mode` on `reusable-security-full` / `reusable-publish-results`.

## Modes

| Mode | Behavior |
|------|----------|
| `none` | Default for PR/push templates — no git writes |
| `branch` | Commit under `security-results/<YYYY-MM-DD>/` and `security-results/latest/` on branch `security-results` (configurable) |
| `pull-request` | Same files on `chore/security-results`; open/update a PR into the default branch |

Publishing runs with `if: always()` so failed scanners still produce a summary. Aggregation also writes **`findings-deduped.json`**: unique findings keyed by rule + location + message, with a severity rollup and which tools reported each issue (SARIF only).

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
    uses: OWNER/mega-cicd-security/.github/workflows/reusable-security-full.yml@SHA
    with:
      results-publish-mode: pull-request
```

Keep PR/push workflows on `results-publish-mode: none` so feature PRs are not filled with report commits.

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
