# GitHub Marketplace listing

Steps to publish scankit for discoverability.

## Repository settings

1. Add **homepage URL**: `https://github.com/virangdoshi/scankit#readme`
2. Add **topics**: `devsecops`, `sarif`, `code-scanning`, `sbom`, `iac-security`, `supply-chain`, `github-actions`, `reusable-workflows`, `security`, `sast`, `sca`
3. Ensure **LICENSE** (MIT) and **SECURITY.md** are present.

## Marketplace submission

Scankit is a **reusable workflow library**, not a single Action. List it as:

- **Name**: Scankit — OSS security scanning for GitHub Actions
- **Category**: Code quality / Security
- **Description**: Kitchen-sink reusable workflows with ecosystem detection, diff-aware PR scans, SARIF, and optional results publish.

Link primary entrypoint:

```text
.github/workflows/reusable-security-full.yml
```

Documentation links:

- [Quick start](docs/quickstart.md)
- [Demo repo](https://github.com/virangdoshi/scankit-demo)

## Verification checklist

- [ ] Public repo (or documented private-library access)
- [ ] Tagged releases (`v1.x.x`)
- [ ] CI badge green
- [ ] README quick start + templates
- [ ] No secrets in workflows

Submit via GitHub → **Settings → Marketplace** (or Partner program if required for workflow listings).
