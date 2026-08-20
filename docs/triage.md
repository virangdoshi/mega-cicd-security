# Finding triage

How to interpret overlapping results from scankit’s kitchen-sink design.

## Why overlap exists

Scankit runs **many OSS scanners by design**. The same CVE or misconfiguration may appear from Trivy, Grype, and OSV-Scanner. That redundancy catches blind spots — triage once in **GitHub Code Scanning** or the sticky PR comment, not by disabling tools prematurely.

## Dedup layer

[`scripts/aggregate-results.sh`](../scripts/aggregate-results.sh) builds `findings-deduped.json`:

- Key: rule + location + message prefix
- Tracks which **tools** reported each unique finding
- PR comment shows **multi-tool overlap** count

## Categories

Findings are grouped heuristically:

| Category | Examples |
|----------|----------|
| secrets | Gitleaks, TruffleHog, detect-secrets |
| sca | Trivy, Grype, OSV, pip-audit |
| sast | Semgrep, CodeQL, Bandit |
| iac | Checkov, KICS, Terrascan |
| supply-chain | Scorecard, pinact, GuardDog |
| container | Hadolint, Trivy image |
| privacy | Bearer, Presidio |
| api | Spectral, vacuum |

## Severity normalization

SARIF levels map to **HIGH / MEDIUM / LOW** in the PR report. `CRITICAL` displays as **HIGH**.

## Recommended workflow

1. **PRs**: fix HIGH from sticky comment, **inline review threads** (`pr-report-mode: all`), or Code Scanning; use `fail-on-severity: HIGH`.
2. **Noise**: set `pr-report-mode: comment` or `none` (skip inline with `both`; use `all` only when you want threads).
3. **Overlap**: if three SCA tools agree, fix once — do not require three separate tickets.
4. **Scheduled audit**: `profile: audit` + `results-publish-mode: pull-request` for security team review.

## Export

- **DefectDojo**: `./scripts/export-defectdojo.sh artifacts/ scankit-sarif.zip`
- **Trends**: `./scripts/trend-summary.sh security-results`
