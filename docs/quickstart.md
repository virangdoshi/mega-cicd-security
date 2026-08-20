# 5-minute adopt

Get scankit running on an app repo in about five minutes.

## Prerequisites

1. **Actions** enabled on the app repo.
2. **Code Scanning** enabled: Settings → Code security → Code scanning (public repos: free).
3. **Dependency graph** enabled if you want Dependency Review on PRs.

## Steps

### 1. Copy a starter workflow

```bash
curl -o .github/workflows/security.yml \
  https://raw.githubusercontent.com/virangdoshi/scankit/main/templates/security-minimal.yml
```

Or copy [`templates/security-minimal.yml`](../templates/security-minimal.yml) manually.

### 2. Replace owner and pin SHA

Edit `.github/workflows/security.yml`:

- Replace `OWNER/scankit` with your org or `virangdoshi/scankit`.
- Pin a **commit SHA** from [Releases](https://github.com/virangdoshi/scankit/releases) (not `@main`).

### 3. Grant permissions

The workflow file includes the required permission ceiling. For **scan-only** (no PR comments), use [`templates/security-scan-only.yml`](../templates/security-scan-only.yml) instead.

### 4. Open a pull request

On the first PR you should see:

- A **sticky scankit comment** (full suite with default `pr-report-mode`)
- **Code Scanning** alerts for SARIF-capable tools
- **Artifacts** with raw reports

### 5. Tune

| Goal | Change |
|------|--------|
| Faster CI | `profile: minimal` (default in minimal template) |
| Full coverage | `profile: standard` + [`security-all.yml`](../templates/security-all.yml) |
| Compliance audit | `profile: audit` + [`security-audit.yml`](../templates/security-audit.yml) |
| Known-bad tree | `profile: soak` or `fail-on-severity: NONE` |
| Repo config file | Copy [`templates/scankit.yml.example`](../templates/scankit.yml.example) → `.scankit.yml` |

## Optional: gh CLI one-liner

```bash
gh api repos/virangdoshi/scankit/releases/latest --jq .tag_name
# Use the release commit SHA in your workflow pin
```

## Try the demo

See the live demo app: [virangdoshi/scankit-demo](https://github.com/virangdoshi/scankit-demo) (polyglot sample with soak + gate workflows).

## Next

- [Adoption guide](adoption.md) — org rollout, private libraries, scan scope
- [Configuration](config.md) — `.scankit.yml`
- [Profiles](../README.md#configuration) — minimal / standard / audit / soak
