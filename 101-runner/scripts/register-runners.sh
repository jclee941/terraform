#!/usr/bin/env bash
# =============================================================================
# Register Organization-level GitHub Actions Runners
# =============================================================================
# Registers multiple runner instances at the org level. Each instance
# automatically serves ALL repositories in the organization.
#
# Environment:
#   GITHUB_TOKEN   — Required. GitHub PAT with admin:org scope.
#   GITHUB_ORG     — Required. GitHub organization (e.g. qws941-lab).
#   RUNNER_COUNT   — Number of runner instances (default: 2).
#   RUNNER_VERSION — Runner binary version (default: 2.322.0).
#   RUNNER_ARCH    — Runner architecture (default: linux-x64).
#
# Usage:
#   GITHUB_TOKEN="ghp_xxx" GITHUB_ORG="qws941-lab" ./register-runners.sh
#   RUNNER_COUNT=3 GITHUB_TOKEN="ghp_xxx" GITHUB_ORG="qws941-lab" ./register-runners.sh
# =============================================================================

set -euo pipefail

GITHUB_TOKEN="${GITHUB_TOKEN:?Error: GITHUB_TOKEN is required}"
GITHUB_ORG="${GITHUB_ORG:?Error: GITHUB_ORG is required}"
GITHUB_API="https://api.github.com"

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

# --- Setup Runner Instance ---------------------------------------------------
setup_runner_instance() {
    local instance="$1"
    local runner_name="homelab-101-${instance}"
    local runner_dir="${RUNNER_BASE}/instance-${instance}"
    local tarball="actions-runner-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz"
    local service_name="github-runner-${instance}"

    log "Setting up org runner instance ${instance} (runner: ${runner_name})..."

    # Create runner directory
    sudo -u "${RUNNER_USER}" mkdir -p "${runner_dir}"

    # Extract runner (use cached tarball)
    if [[ ! -f "${runner_dir}/run.sh" ]]; then
        sudo -u "${RUNNER_USER}" tar xzf "/tmp/${tarball}" -C "${runner_dir}" 2>/dev/null
    fi

    # Get org-level registration token
    local token
    token=$(curl -s -X POST \
        -H "Authorization: token ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        "${GITHUB_API}/orgs/${GITHUB_ORG}/actions/runners/registration-token" | jq -r '.token // empty')

    if [[ -z "${token}" ]]; then
        warn "Failed to get org registration token for instance ${instance}. Check GITHUB_TOKEN permissions (admin:org scope required)."
        return 1
    fi

    # Configure runner at org level
    sudo -u "${RUNNER_USER}" bash -c "
        cd '${runner_dir}' && \
        ./config.sh \
            --url 'https://github.com/${GITHUB_ORG}' \
            --token '${token}' \
            --name '${runner_name}' \
            --labels '${RUNNER_LABELS}' \
            --work '${runner_dir}/_work' \
            --replace \
            --unattended
    " 2>&1 || {
        warn "Failed to register org runner instance ${instance}. Skipping."
        return 1
    }

    # Create systemd service
    cat > "/etc/systemd/system/${service_name}.service" <<EOF
[Unit]
Description=GitHub Actions Runner - org instance ${instance}
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
    log "=== Org-level Runner Registration ==="
    log "Organization: ${GITHUB_ORG}"
    log "Instances: ${RUNNER_COUNT}"
    log ""

    # Download runner tarball once
    local tarball="actions-runner-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz"
    if [[ ! -f "/tmp/${tarball}" ]]; then
        log "Downloading runner v${RUNNER_VERSION}..."
        curl -sL "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${tarball}" -o "/tmp/${tarball}"
    fi

    sudo -u "${RUNNER_USER}" mkdir -p "${RUNNER_BASE}"

    local success=0
    local failed=0

    for i in $(seq 1 "${RUNNER_COUNT}"); do
        log ""
        log "--- Instance ${i} of ${RUNNER_COUNT} ---"

        if setup_runner_instance "${i}"; then
            success=$((success + 1))
        else
            failed=$((failed + 1))
        fi
    done

    log ""
    log "=== Registration Complete ==="
    log "Total: ${RUNNER_COUNT} | Success: ${success} | Failed: ${failed}"
    log ""
    log "Each runner serves ALL repos in ${GITHUB_ORG} automatically."
    log ""
    log "Manage runners:"
    log "  systemctl list-units 'github-runner-*'"
    log "  systemctl status github-runner-<instance>"
    log "  journalctl -u github-runner-<instance> -f"
}

main "$@"
