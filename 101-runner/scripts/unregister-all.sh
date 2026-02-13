#!/usr/bin/env bash
# =============================================================================
# Unregister All GitHub Actions Runners
# =============================================================================
# Cleanly removes all runner registrations and systemd services.
#
# Usage:
#   GITHUB_TOKEN="ghp_xxx" GITHUB_USER="qws941" ./unregister-all.sh
# =============================================================================

set -euo pipefail

GITHUB_TOKEN="${GITHUB_TOKEN:?Error: GITHUB_TOKEN is required}"
GITHUB_USER="${GITHUB_USER:?Error: GITHUB_USER is required}"
GITHUB_API="https://api.github.com"

RUNNER_USER="runner"
RUNNER_BASE="/home/${RUNNER_USER}/runners"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[+]${NC} $*"; }
err() { echo -e "${RED}[-]${NC} $*" >&2; }

log "=== Unregistering All Runners ==="

# Stop and disable all runner services
for service in /etc/systemd/system/github-runner-*.service; do
    [[ -f "${service}" ]] || continue
    svc_name=$(basename "${service}" .service)
    log "Stopping ${svc_name}..."
    systemctl stop "${svc_name}" 2>/dev/null || true
    systemctl disable "${svc_name}" 2>/dev/null || true
    rm -f "${service}"
done

# Also handle single runner service
systemctl stop github-runner.service 2>/dev/null || true
systemctl disable github-runner.service 2>/dev/null || true
rm -f /etc/systemd/system/github-runner.service

systemctl daemon-reload

# Remove runner configs
for runner_dir in "${RUNNER_BASE}"/*/; do
    [[ -d "${runner_dir}" ]] || continue
    repo=$(basename "${runner_dir}")

    log "Removing runner config for ${repo}..."

    # Get removal token
    token=$(curl -s -X POST \
        -H "Authorization: token ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        "${GITHUB_API}/repos/${GITHUB_USER}/${repo}/actions/runners/remove-token" | jq -r '.token // empty' 2>/dev/null)

    if [[ -n "${token}" ]]; then
        sudo -u "${RUNNER_USER}" bash -c "cd '${runner_dir}' && ./config.sh remove --token '${token}'" 2>/dev/null || true
    fi
done

# Clean up
rm -rf "${RUNNER_BASE}"
rm -rf "/home/${RUNNER_USER}/actions-runner"
rm -rf "/home/${RUNNER_USER}/_work"

log "All runners unregistered and cleaned up."
