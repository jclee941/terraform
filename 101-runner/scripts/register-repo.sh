#!/usr/bin/env bash
# =============================================================================
# Register GitHub Actions Runner to Additional Repository
# =============================================================================
# Adds the self-hosted runner to a specific repo.
#
# Usage:
#   GITHUB_TOKEN="ghp_xxx" GITHUB_USER="qws941" ./register-repo.sh <repo-name>
# =============================================================================

set -euo pipefail

GITHUB_TOKEN="${GITHUB_TOKEN:?Error: GITHUB_TOKEN is required}"
GITHUB_USER="${GITHUB_USER:?Error: GITHUB_USER is required}"
GITHUB_API="https://api.github.com"
REPO="${1:?Error: Repository name required. Usage: ./register-repo.sh <repo-name>}"

RUNNER_USER="runner"
RUNNER_DIR="/home/${RUNNER_USER}/actions-runner"
RUNNER_LABELS="self-hosted,linux,x64,homelab"
RUNNER_NAME="homelab-runner"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log() { echo -e "${GREEN}[+]${NC} $*"; }
err() { echo -e "${RED}[-]${NC} $*" >&2; }

# Stop existing runner
log "Stopping runner service..."
systemctl stop github-runner.service 2>/dev/null || true

# Remove existing config
log "Removing existing runner config..."
sudo -u "${RUNNER_USER}" bash -c "
    cd '${RUNNER_DIR}' && \
    ./config.sh remove --token \$(curl -s -X POST \
        -H 'Authorization: token ${GITHUB_TOKEN}' \
        -H 'Accept: application/vnd.github.v3+json' \
        '${GITHUB_API}/repos/${GITHUB_USER}/${REPO}/actions/runners/remove-token' | jq -r '.token')
" 2>/dev/null || true

# Get new registration token
log "Getting registration token for ${GITHUB_USER}/${REPO}..."
TOKEN=$(curl -s -X POST \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    "${GITHUB_API}/repos/${GITHUB_USER}/${REPO}/actions/runners/registration-token" | jq -r '.token')

if [[ -z "${TOKEN}" || "${TOKEN}" == "null" ]]; then
    err "Failed to get registration token. Check GITHUB_TOKEN permissions."
    exit 1
fi

# Register runner
log "Registering runner for ${GITHUB_USER}/${REPO}..."
WORK_DIR="/home/${RUNNER_USER}/_work/${REPO}"
sudo -u "${RUNNER_USER}" mkdir -p "${WORK_DIR}"

sudo -u "${RUNNER_USER}" bash -c "
    cd '${RUNNER_DIR}' && \
    ./config.sh \
        --url 'https://github.com/${GITHUB_USER}/${REPO}' \
        --token '${TOKEN}' \
        --name '${RUNNER_NAME}' \
        --labels '${RUNNER_LABELS}' \
        --work '${WORK_DIR}' \
        --replace \
        --unattended
"

# Restart runner
log "Restarting runner service..."
systemctl start github-runner.service

log "Done! Runner registered for ${GITHUB_USER}/${REPO}"
log "Status: systemctl status github-runner"
