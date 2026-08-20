#!/usr/bin/env bash
# Map scankit profile names to category/tool flags and effective scan settings.
# Usage: resolve-profile.sh <profile> [out-file]
# Writes key=value lines to out-file (GITHUB_OUTPUT format) or stdout.
set -euo pipefail

PROFILE="${1:-standard}"
OUT="${2:-}"

emit() {
  if [[ -n "$OUT" ]]; then
    printf '%s\n' "$1" >>"$OUT"
  else
    printf '%s\n' "$1"
  fi
}

# Defaults (standard profile)
run_secrets=true
run_sca=true
run_sast=true
run_container=true
run_iac=true
run_sbom=true
run_supply=true
run_privacy=true
run_api=true
run_malware=true
run_meta=true
run_dast=false

enable_codeql=true
enable_semgrep=true
enable_bandit=true
enable_gosec=true
enable_brakeman=true
enable_spotbugs=true
enable_devskim=true
enable_shellcheck=true
enable_actionlint=true
enable_zizmor=true
enable_harden_runner=true

effective_scan_scope=""
effective_fail_on=""
effective_pr_report=""

case "$PROFILE" in
  minimal)
    run_container=false
    run_iac=false
    run_sbom=false
    run_supply=false
    run_privacy=false
    run_api=false
    run_malware=false
    enable_codeql=false
    enable_bandit=false
    enable_gosec=false
    enable_brakeman=false
    enable_spotbugs=false
    enable_devskim=false
    enable_shellcheck=false
    enable_zizmor=false
    enable_harden_runner=false
    ;;
  standard)
    ;;
  audit)
    effective_scan_scope=full
    effective_fail_on=HIGH
    ;;
  soak)
    effective_fail_on=NONE
    effective_pr_report=comment
    ;;
  *)
    echo "Unknown profile: $PROFILE (use minimal|standard|audit|soak)" >&2
    exit 1
    ;;
esac

emit "run_secrets=$run_secrets"
emit "run_sca=$run_sca"
emit "run_sast=$run_sast"
emit "run_container=$run_container"
emit "run_iac=$run_iac"
emit "run_sbom=$run_sbom"
emit "run_supply=$run_supply"
emit "run_privacy=$run_privacy"
emit "run_api=$run_api"
emit "run_malware=$run_malware"
emit "run_meta=$run_meta"
emit "run_dast=$run_dast"
emit "enable-codeql=$enable_codeql"
emit "enable-semgrep=$enable_semgrep"
emit "enable-bandit=$enable_bandit"
emit "enable-gosec=$enable_gosec"
emit "enable-brakeman=$enable_brakeman"
emit "enable-spotbugs=$enable_spotbugs"
emit "enable-devskim=$enable_devskim"
emit "enable-shellcheck=$enable_shellcheck"
emit "enable-actionlint=$enable_actionlint"
emit "enable-zizmor=$enable_zizmor"
emit "enable-harden-runner=$enable_harden_runner"
emit "effective_scan_scope=$effective_scan_scope"
emit "effective_fail_on=$effective_fail_on"
emit "effective_pr_report=$effective_pr_report"
