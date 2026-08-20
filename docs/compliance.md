# Compliance mapping

Lightweight mapping of scankit categories to common control frameworks. **Not a certification** — use for audit conversations and gap analysis.

## OWASP ASVS (V4) — representative mappings

| ASVS area | Scankit categories | Tools (examples) |
|-----------|-------------------|------------------|
| V1 Architecture | supply-chain, meta | Scorecard, actionlint, zizmor |
| V2 Authentication | sast, secrets | Semgrep, CodeQL, Gitleaks |
| V3 Session | sast | Semgrep, CodeQL |
| V4 Access control | sast | Semgrep, CodeQL |
| V5 Validation | sast | Semgrep, Bandit |
| V6 Stored crypto | sast, secrets | Semgrep, detect-secrets |
| V7 Error handling | sast | Semgrep, CodeQL |
| V8 Data protection | privacy, secrets | Bearer, Presidio, Gitleaks |
| V9 Communication | api, container | Spectral, Trivy image, Cosign |
| V10 Malicious code | malware, supply-chain | ClamAV, GuardDog, capa |
| V11 Business logic | sast | Semgrep (custom rules) |
| V12 Files/resources | sast, iac | Checkov, KICS |
| V13 API | api | Spectral, vacuum, IBM validator |
| V14 Config | iac, meta, container | Checkov, Hadolint, pinact |

## NIST SSDF (SP 800-218) practices

| Practice | Scankit coverage |
|----------|------------------|
| PO.3 Toolchain | meta, supply-chain (pinact, ratchet) |
| PS.1 Protect software | secrets, supply-chain |
| PW.4 Review code | sast, secrets |
| PW.7 Reuse third-party | sca, sbom |
| PW.8 Reuse tooling | sca, supply-chain |
| RV.1 Vulnerabilities | sca, sast, container |
| RV.2 Vulnerability disclosure | (process — not automated) |

## SOC 2 CC7.2 (monitoring)

| Control theme | Scankit contribution |
|---------------|---------------------|
| Detection of security events | SARIF → Code Scanning, PR report |
| Vulnerability management | SCA + SAST findings, optional `security-results/` publish |
| Change monitoring | Diff-scoped PR scans, Dependency Review |

## Gaps (address outside scankit)

- Penetration testing / DAST on production
- Runtime WAF / SIEM correlation
- Identity/access reviews (IAM, PAM)
- Formal risk acceptance workflow

See [vs-alternatives.md](vs-alternatives.md) for tool positioning.
