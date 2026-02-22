#!/usr/bin/env bash
# Terraform Drift Detection
# Runs `terraform plan -detailed-exitcode` and alerts on drift.
# Deploy as systemd timer on the host where Terraform runs.
#
# Exit codes from terraform plan -detailed-exitcode:
#   0 = No changes (no drift)
#   1 = Error
#   2 = Changes detected (drift!)

set -uo pipefail

# Cleanup on unexpected exit
cleanup() {
  local exit_code=$?
  if [ $exit_code -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') INTERRUPTED: Script exited with code $exit_code" >> "${LOG_FILE:-/var/log/terraform-drift.log}"
  fi
}
trap cleanup EXIT

TERRAFORM_DIR="${TERRAFORM_DIR:-/home/jclee/dev/terraform/100-pve/envs/prod}"
GRAFANA_URL="${GRAFANA_URL:-http://192.168.50.104:3000}"
GRAFANA_TOKEN="${GRAFANA_TOKEN:?GRAFANA_TOKEN env var is required - generate via Grafana UI or Vault}"
LOG_FILE="/var/log/terraform-drift.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

log() {
  echo "${TIMESTAMP} $1" >> "$LOG_FILE"
}

PLAN_OUTPUT=$(cd "$TERRAFORM_DIR" && terraform plan -detailed-exitcode -no-color -input=false 2>&1)
EXIT_CODE=$?

case $EXIT_CODE in
  0)
    log "OK: No drift detected."
    ;;
  1)
    log "ERROR: Terraform plan failed."
    log "Output: ${PLAN_OUTPUT:0:500}"
    curl -s -X POST "${GRAFANA_URL}/api/annotations" \
      -H "Authorization: Bearer ${GRAFANA_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{
        \"text\": \"Terraform plan ERROR - check logs\",
        \"tags\": [\"terraform\", \"drift\", \"error\"]
      }" > /dev/null 2>&1
    ;;
  2)
    DRIFT_SUMMARY=$(echo "$PLAN_OUTPUT" | grep -E '^(Plan:|  #|  ~|  \+|  -)' | head -20)
    log "DRIFT: Changes detected!"
    log "Summary: ${DRIFT_SUMMARY}"

    ESCAPED_SUMMARY=$(echo "$DRIFT_SUMMARY" | sed 's/"/\\"/g' | tr '\n' ' ')
    curl -s -X POST "${GRAFANA_URL}/api/annotations" \
      -H "Authorization: Bearer ${GRAFANA_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{
        \"text\": \"Terraform DRIFT detected: ${ESCAPED_SUMMARY}\",
        \"tags\": [\"terraform\", \"drift\", \"warning\"]
      }" > /dev/null 2>&1

    log "Grafana annotation posted."
    ;;
esac

exit 0
