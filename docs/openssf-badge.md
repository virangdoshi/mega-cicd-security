# OpenSSF Best Practices badge

Checklist before applying at [bestpractices.dev](https://www.bestpractices.dev/).

## Project basics

- [x] Public GitHub repo with OSS license (MIT)
- [x] SECURITY.md with vulnerability reporting
- [x] Stable version tags (semver)
- [ ] Website or comprehensive README (README + docs/)

## Change control

- [x] Version control (Git)
- [x] CHANGELOG.md (Keep a Changelog)
- [ ] CONTRIBUTING.md (added in v1.2)
- [x] CI runs on PRs ([ci-self-test.yml](../.github/workflows/ci-self-test.yml))

## Quality

- [x] Automated tests (`./tests/run.sh`)
- [x] Action pin enforcement (`scripts/check-action-pins.sh`)
- [x] Hash-pinned Python deps (`.github/pinned/`)

## Security

- [x] No known hardcoded credentials
- [x] Expression injection hardening (env: not ${{ }} in run)
- [x] Default-disable untrusted builds (`enable-image-build`, `enable-code-build`)
- [x] Dependabot for Actions

## Application

1. Sign in at bestpractices.dev with GitHub.
2. Add project `virangdoshi/scankit`.
3. Complete questionnaire; link to this doc and CONTRIBUTING.md.
4. Add badge to README once passing:

```markdown
[![OpenSSF Best Practices](https://www.bestpractices.dev/projects/XXXX/badge)](https://www.bestpractices.dev/projects/XXXX)
```

Replace `XXXX` with assigned project ID after approval.
