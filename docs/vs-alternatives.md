# Scankit vs alternatives

Honest positioning — pick the right tool for your situation.

## vs DIY (Trivy + CodeQL + Gitleaks)

| | DIY | Scankit |
|---|-----|---------|
| Setup | Hours per tool, drift over time | One `workflow_call`, templates |
| Coverage | What you wire | 50+ OSS tools, ecosystem-aware |
| Overlap | You choose | Intentional (triage in Code Scanning) |
| Supply chain | You pin each action | SHA-pinned library + Dependabot |
| Best for | One-tool shops, strict minimalism | Teams wanting broad OSS coverage fast |

## vs GitHub Advanced Security (GHAS)

| | GHAS | Scankit |
|---|------|---------|
| Cost | GHAS license for private repos | Free OSS scanners + Actions minutes |
| CodeQL | Native, deep | Included via CodeQL action |
| Secret scanning | GitHub-native push/PR | Gitleaks, TruffleHog, detect-secrets, secretlint |
| Dependency | Dependabot + Dependency Review | OSV, Trivy, Grype, pip-audit, … |
| Best for | Enterprise all-in on GitHub | Complement GHAS or bootstrap before GHAS |

Scankit runs alongside GHAS — many orgs use both.

## vs commercial platforms (Snyk, Semgrep App, etc.)

| | Commercial SaaS | Scankit |
|---|-----------------|---------|
| Triage UX | Rich dashboards | Code Scanning + sticky PR comment |
| Policy | Central SaaS policy | `.scankit.yml` + org wrapper template |
| Data residency | Vendor cloud | Runs in your Actions runners |
| Best for | Budget for unified SaaS | OSS-first, air-gapped-friendly CI |

## Scankit sweet spot

> **Batteries-included OSS security library for GitHub Actions** — ecosystem-aware, org-rollout via `workflow_call`, diff-aware PRs, optional git publish.

Not a replacement for threat modeling, DAST against production, or live-cluster CIS (kube-bench). Optional DAST module targets **staging URLs only**.
