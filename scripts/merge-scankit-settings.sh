#!/usr/bin/env bash
# Merge .scankit.yml (optional), workflow inputs, and profile defaults.
# Precedence: config file (base) <- workflow CLI flags <- profile effective overrides.
set -euo pipefail

OUT="${1:?out-file required}"
shift

CONFIG=""
PROFILE=""
SCAN_SCOPE=""
FAIL_ON=""
PR_REPORT=""
ENABLE_DAST=""
DAST_URL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config) CONFIG="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --scan-scope) SCAN_SCOPE="$2"; shift 2 ;;
    --fail-on) FAIL_ON="$2"; shift 2 ;;
    --pr-report) PR_REPORT="$2"; shift 2 ;;
    --enable-dast) ENABLE_DAST="$2"; shift 2 ;;
    --dast-url) DAST_URL="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Config file base
if [[ -n "$CONFIG" && -f "$CONFIG" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" || "$line" != *"="* ]] && continue
    key="${line%%=*}"
    val="${line#*=}"
    case "$key" in
      profile) [[ -z "$PROFILE" ]] && PROFILE="$val" ;;
      scan-scope) [[ -z "$SCAN_SCOPE" ]] && SCAN_SCOPE="$val" ;;
      fail-on-severity) [[ -z "$FAIL_ON" ]] && FAIL_ON="$val" ;;
      pr-report-mode) [[ -z "$PR_REPORT" ]] && PR_REPORT="$val" ;;
      enable-dast) [[ -z "$ENABLE_DAST" ]] && ENABLE_DAST="$val" ;;
      dast-url) [[ -z "$DAST_URL" ]] && DAST_URL="$val" ;;
    esac
  done < <(bash "$SCRIPT_DIR/load-scankit-config.sh" "$CONFIG" /dev/stdout || true)
fi

# Defaults when still unset
[[ -z "$PROFILE" ]] && PROFILE="standard"
[[ -z "$SCAN_SCOPE" ]] && SCAN_SCOPE="auto"
[[ -z "$FAIL_ON" ]] && FAIL_ON="HIGH"
[[ -z "$PR_REPORT" ]] && PR_REPORT="both"
[[ -z "$ENABLE_DAST" ]] && ENABLE_DAST="false"
[[ -z "$DAST_URL" ]] && DAST_URL=""

PROF_OUT="$(mktemp)"
bash "$SCRIPT_DIR/resolve-profile.sh" "$PROFILE" "$PROF_OUT"

while IFS= read -r line; do
  [[ -z "$line" || "$line" != *"="* ]] && continue
  key="${line%%=*}"
  val="${line#*=}"
  case "$key" in
    effective_scan_scope) [[ -n "$val" ]] && SCAN_SCOPE="$val" ;;
    effective_fail_on) [[ -n "$val" ]] && FAIL_ON="$val" ;;
    effective_pr_report) [[ -n "$val" ]] && PR_REPORT="$val" ;;
  esac
  echo "$line" >>"$OUT"
done < "$PROF_OUT"

{
  echo "scan_scope=$SCAN_SCOPE"
  echo "fail_on_severity=$FAIL_ON"
  echo "pr_report_mode=$PR_REPORT"
  echo "enable_dast=$ENABLE_DAST"
  echo "dast_url=$DAST_URL"
} >>"$OUT"

rm -f "$PROF_OUT"
