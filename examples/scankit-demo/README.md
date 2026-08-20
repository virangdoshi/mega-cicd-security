# scankit-demo

Live demo app for [scankit](https://github.com/virangdoshi/scankit) — polyglot sample with security workflows.

## What's inside

- Python (`main.py`, `requirements.txt`)
- Node (`package.json`)
- Dockerfile + GitHub Actions CI workflow
- Two security workflows:
  - **soak** — `fail-on-severity: NONE` (always green, shows findings)
  - **gate** — `fail-on-severity: HIGH` (demonstrates CI gate)

## Publish as standalone repo

```bash
# From scankit repo root
gh repo create scankit-demo --public --source=examples/scankit-demo --push
```

Or copy `examples/scankit-demo/` to a new repository manually.

## Wire scankit

1. Enable **Code Scanning** on the demo repo.
2. Update workflow SHAs to a [scankit release](https://github.com/virangdoshi/scankit/releases).
3. Open a PR — expect sticky PR comment + Code Scanning alerts.

## Expected findings

This demo intentionally includes common patterns scanners flag (outdated deps, Dockerfile hints, etc.). Use **soak** mode to explore without failing CI.

## Screenshots

After first PR run, capture:

- Sticky PR comment (scankit security report)
- Security → Code scanning alerts
- Actions artifacts

Add screenshots to this README in the published demo repo.
