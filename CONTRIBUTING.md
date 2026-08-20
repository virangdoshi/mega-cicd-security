# Contributing to scankit

Thanks for helping improve scankit.

## Development setup

```bash
git clone https://github.com/virangdoshi/scankit.git
cd scankit
./tests/run.sh
./scripts/detect-ecosystems.sh . /tmp/eco.json
./scripts/run-local.sh --profile minimal --path .
```

## Adding a scanner

1. Add job to the appropriate [`.github/workflows/reusable-*.yml`](.github/workflows/) category workflow.
2. Add `enable-<tool>` input (default `true`) and `if:` guard with ecosystem + scan-scope flags.
3. Upload SARIF to Code Scanning when the tool supports it.
4. Pin third-party Actions to **commit SHA** (run `./scripts/check-action-pins.sh`).
5. Add row to [`docs/scanners.md`](docs/scanners.md).
6. Add fixture under [`tests/fixtures/`](tests/fixtures/) if ecosystem detection changes.
7. Extend [`tests/run.sh`](tests/run.sh) if new scripts or templates need coverage.

## Python tool pins

```bash
pip-compile --generate-hashes --allow-unsafe \
  --output-file .github/pinned/<tool>.txt \
  <(printf '<package>==<version>\n')
```

## Release binaries

Add SHA256 to [`.github/pinned/checksums.sha256`](.github/pinned/checksums.sha256); verify with [`scripts/verify-sha256.sh`](scripts/verify-sha256.sh).

## Template SHA bumps

After each release:

```bash
./scripts/bump-template-pins.sh <release-commit-sha>
```

## Pull requests

- Keep diffs focused.
- Run `./tests/run.sh` before opening PR.
- Update [`CHANGELOG.md`](CHANGELOG.md) under `[Unreleased]`.

## Code of conduct

Be respectful. Security findings in issues/PRs may be sensitive — avoid posting live secrets.
