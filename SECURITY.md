# Security Policy

## Supported versions

This repository publishes reusable GitHub Actions workflows. Use a **commit SHA** (preferred) or an immutable release tag of this library. `@main` is not supported for production callers.

| Track | Supported |
|-------|-----------|
| Latest commit SHA / newest release tag | Yes |
| Older tags | Best-effort; upgrade when Dependabot opens bumps |
| `@main` floating ref | No |

## Reporting a vulnerability

Please **do not** open a public issue for security problems in this library.

1. Use GitHub **Private vulnerability reporting**: https://github.com/virangdoshi/scankit/security/advisories/new
2. Or contact the maintainers listed in [CODEOWNERS](CODEOWNERS) with a description, impact, and reproduction steps.

We aim to acknowledge reports within **7 days** and to ship a fix or mitigation for confirmed issues as quickly as practical.

## Scope

In scope:

- Reusable workflows and composite actions under `.github/`
- Helper scripts under `scripts/`
- Supply-chain issues in pinned third-party Actions this repo vendors by SHA

Out of scope:

- Vulnerabilities in scanners this library *invokes* (report upstream)
- Misconfiguration in *caller* repositories (permissions, publish mode, enabling image/code builds on untrusted PRs)
- Test fixtures under `tests/fixtures/` (intentionally outdated packages for detector tests)

## Hardening expectations for callers

- For `reusable-security-full`, grant the documented permission ceiling (`contents`/`pull-requests`/`security-events: write`) — required even when not publishing
- Keep `enable-image-build` / `enable-code-build` off for untrusted `pull_request` workflows
- Do not publish secret-scanner raw artifacts into git
- Prefer `scan-scope: auto` on PR workflows; use `scan-scope: full` for scheduled/baseline audits
