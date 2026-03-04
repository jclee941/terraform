#!/usr/bin/env bash
# =============================================================================
# Register GitHub Actions Runner to a Specific Repository
# =============================================================================
# Registers runner instance(s) for a single repo. Supports multi-instance
# deployment where each instance is independently registered.
#
# Environment:
#   GITHUB_TOKEN  — Required. GitHub PAT with repo/admin:org scope.
#   GITHUB_USER   — Required. GitHub username (e.g. qws941).
#   RUNNER_COUNT   — Number of runner instances (default: 2).
#   RUNNER_VERSION — Runner binary version (default: 2.322.0).
#   RUNNER_ARCH    — Runner architecture (default: linux-x64).
#
# Usage:
#   ./register-repo.sh <repo-name>              # Register all instances
#   ./register-repo.sh <repo-name> 1             # Register instance 1 only
#   ./register-repo.sh <repo-name> 3             # Register instance 3 only
# =============================================================================

set -euo pipefail

GITHUB_TOKEN="${GITHUB_TOKEN:?Error: GITHUB_TOKEN is required}"
GITHUB_USER="${GITHUB_USER:?Error: GITHUB_USER is required}"
GITHUB_API="https://api.github.com"
REPO="${1:?Error: Repository name required. Usage: ./register-repo.sh <repo-name> [instance-number]}"
INSTANCE_NUM="${2:-}"

RUNNER_USER="runner"
RUNNER_BASE="/home/${RUNNER_USER}/runners"
RUNNER_VERSION="${RUNNER_VERSION:-2.322.0}"
RUNNER_ARCH="${RUNNER_ARCH:-linux-x64}"
RUNNER_LABELS="self-hosted,linux,x64,homelab"
RUNNER_COUNT="${RUNNER_COUNT:-2}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[-]${NC} $*" >&2; }

# --- Register a single instance for a repo ----------------------------------
register_instance() {
    local instance="$1"
    local runner_name="homelab-101-${instance}"
    local runner_dir="${RUNNER_BASE}/instance-${instance}/${REPO}"
    local tarball="actions-runner-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz"
    local service_name="github-runner-${instance}-${REPO}"

    log "Registering instance ${instance} for ${GITHUB_USER}/${REPO} (runner: ${runner_name})..."

    # Stop existing service if running
    systemctl stop "${service_name}.service" 2>/dev/null || true

    # Create runner directory
    sudo -u "${RUNNER_USER}" mkdir -p "${runner_dir}"

    # Extract runner (use cached tarball)
    if [[ ! -f "${runner_dir}/run.sh" ]]; then
        sudo -u "${RUNNER_USER}" tar xzf "/tmp/${tarball}" -C "${runner_dir}" 2>/dev/null
    fi

    # Remove existing config if present
    if [[ -f "${runner_dir}/.runner" ]]; then
        local remove_token
        remove_token=$(curl -s -X POST \
            -H "Authorization: token ${GITHUB_TOKEN}" \
            -H "Accept: application/vnd.github.v3+json" \
            "${GITHUB_API}/repos/${GITHUB_USER}/${REPO}/actions/runners/remove-token" | jq -r '.token // empty')

        if [[ -n "${remove_token}" ]]; then
            sudo -u "${RUNNER_USER}" bash -c "cd '${runner_dir}' && ./config.sh remove --token '${remove_token}'" 2>/dev/null || true
        fi
    fi

    # Get registration token
    local token
    token=$(curl -s -X POST \
        -H "Authorization: token ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        "${GITHUB_API}/repos/${GITHUB_USER}/${REPO}/actions/runners/registration-token" | jq -r '.token // empty')

    if [[ -z "${token}" || "${token}" == "null" ]]; then
        err "Failed to get registration token for instance ${instance}. Check GITHUB_TOKEN permissions."
        return 1
    fi

    # Configure runner
    sudo -u "${RUNNER_USER}" bash -c "
        cd '${runner_dir}' && \
        ./config.sh \
            --url 'https://github.com/${GITHUB_USER}/${REPO}' \
            --token '${token}' \
            --name '${runner_name}' \
            --labels '${RUNNER_LABELS}' \
            --work '${runner_dir}/_work' \
            --replace \
            --unattended
    " 2>&1 || {
        err "Failed to register instance ${instance} for ${REPO}."
        return 1
    }

    # Create systemd service
    cat > "/etc/systemd/system/${service_name}.service" <<EOF
[Unit]
Description=GitHub Actions Runner - instance ${instance} - ${REPO}
After=network.target docker.service
Wants=docker.service

[Service]
Type=simple
User=${RUNNER_USER}
Group=${RUNNER_USER}
WorkingDirectory=${runner_dir}
ExecStart=${runner_dir}/run.sh
Restart=always
RestartSec=10
KillMode=process
KillSignal=SIGTERM
TimeoutStopSec=5min

Environment="DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1"

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "${service_name}.service"
    systemctl start "${service_name}.service"

    log "Runner started: systemctl status ${service_name}"
}

# --- Main --------------------------------------------------------------------
main() {
    log "=== Register Runner for ${GITHUB_USER}/${REPO} ==="

    # Download runner tarball once
    local tarball="actions-runner-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz"
    if [[ ! -f "/tmp/${tarball}" ]]; then
        log "Downloading runner v${RUNNER_VERSION}..."
        curl -sL "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${tarball}" -o "/tmp/${tarball}"
    fi

    sudo -u "${RUNNER_USER}" mkdir -p "${RUNNER_BASE}"

    if [[ -n "${INSTANCE_NUM}" ]]; then
        # Register specific instance only
        log "Instance: ${INSTANCE_NUM}"
        register_instance "${INSTANCE_NUM}"
    else
        # Register all instances
        log "Instances: 1..${RUNNER_COUNT}"
        local success=0
        local failed=0

        for i in $(seq 1 "${RUNNER_COUNT}"); do
            if register_instance "${i}"; then
                success=$((success + 1))
            else
                failed=$((failed + 1))
            fi
        done

        log ""
        log "=== Registration Complete ==="
        log "Success: ${success} | Failed: ${failed}"
    fi
}

main "$@"
