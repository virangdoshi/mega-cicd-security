# Configuration (`.scankit.yml`)

Optional repo-level config so teams change scan behavior without editing workflow YAML.

## File location

Place at repo root:

- `.scankit.yml` or `.scankit.yaml`

Copy [`templates/scankit.yml.example`](../templates/scankit.yml.example) to start.

## Schema

| Key | Values | Default |
|-----|--------|---------|
| `profile` | `minimal` \| `standard` \| `audit` \| `soak` | `standard` |
| `fail-on-severity` | `CRITICAL` \| `HIGH` \| `MEDIUM` \| `LOW` \| `NONE` | `HIGH` |
| `scan-scope` | `auto` \| `diff` \| `full` | `auto` |
| `pr-report-mode` | `none` \| `comment` \| `annotations` \| `both` | `both` |
| `results-publish-mode` | `none` \| `branch` \| `pull-request` | `none` |
| `enable-scancode` | `true` \| `false` | `false` |
| `enable-dast` | `true` \| `false` | `false` |
| `dast-url` | HTTPS staging URL | (empty) |

## Precedence

1. `.scankit.yml` base values (when `config-path` is set on the workflow)
2. Workflow `with:` inputs **override** config file values
3. Profile effective overrides (`audit` → `scan-scope: full`; `soak` → `fail-on-severity: NONE`)

## Workflow wiring

```yaml
jobs:
  security:
    uses: YOUR_ORG/scankit/.github/workflows/reusable-security-full.yml@SHA
    with:
      config-path: .scankit.yml
      # Optional overrides (win over file):
      # profile: minimal
```

## Governance

Protect `.scankit.yml` with CODEOWNERS so security team approves policy changes:

```
/.scankit.yml @security-team
```

## Local validation

```bash
./scripts/load-scankit-config.sh .scankit.yml
./scripts/merge-scankit-settings.sh /tmp/out --config .scankit.yml --profile standard
cat /tmp/out
```
