# Performance and cost

Guidance for runtime, Actions minutes, and noise reduction.

## Typical job counts

| Profile | Approx. parallel jobs (detected repo) | Notes |
|---------|----------------------------------------|-------|
| `minimal` | ~8–12 | secrets, SCA, Semgrep, actionlint |
| `standard` | ~25–45 | all categories, ecosystem skipping |
| `audit` | ~25–45 | full tree every run |
| `soak` | same as standard | does not fail on findings |

Counts vary by ecosystems detected and diff scope on PRs.

## Runtime estimates (ubuntu-latest)

| Profile | First PR (cold) | Subsequent PR (diff) |
|---------|-----------------|----------------------|
| minimal | ~8–15 min | ~5–10 min |
| standard | ~25–45 min | ~10–20 min |

Heavy tools: ClamAV freshclam, ScanCode (`enable-scancode: true`), CodeQL matrix, container image scans.

## Speed tips

1. Start with **`profile: minimal`** ([`templates/security-minimal.yml`](../templates/security-minimal.yml)).
2. Keep **`enable-scancode: false`** (default).
3. Disable ClamAV on malware workflow: `enable-clamav: false` when calling category workflow.
4. Use **`scan-scope: auto`** on PRs (default) — diff-aware scanning.
5. **Monorepo**: add `paths:` filters on the caller workflow `on.pull_request`.
6. **Category-only**: call `reusable-secrets.yml` + `reusable-sca.yml` instead of full suite.
7. Use **`reusable-security-scan.yml`** when you do not need publish/PR comment jobs.

## Concurrency

Templates use:

```yaml
concurrency:
  group: security-${{ github.ref }}
  cancel-in-progress: true
```

Cancel superseded runs on the same branch to save minutes.

## Benchmarking

After adopting, record wall time from the Actions UI for your repo and update team runbooks. The [demo repo](https://github.com/virangdoshi/scankit-demo) provides a reference polyglot app.
