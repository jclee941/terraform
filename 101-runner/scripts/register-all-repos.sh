#!/usr/bin/env bash
# =============================================================================
# Bulk Register Runner Instances to All GitHub Repos
# =============================================================================
# Uses GitHub API to discover all repos and sets up multiple runner instances
# per repo using the jit-config approach for repo-level runners.
#
# Since GitHub doesn't support user-level (non-org) shared runners,
# this creates a separate runner directory per instance×repo combination
# with independent systemd services.
#
# Environment:
#   GITHUB_TOKEN  — Required. GitHub PAT with repo/admin:org scope.
#   GITHUB_USER   — Required. GitHub username (e.g. qws941).
#   RUNNER_COUNT   — Number of runner instances per repo (default: 2).
#   RUNNER_VERSION — Runner binary version (default: 2.322.0).
#   RUNNER_ARCH    — Runner architecture (default: linux-x64).
#
# Usage:
#   GITHUB_TOKEN="ghp_xxx" GITHUB_USER="qws941" ./register-all-repos.sh
#   RUNNER_COUNT=3 GITHUB_TOKEN="ghp_xxx" GITHUB_USER="qws941" ./register-all-repos.sh
# =============================================================================

set -euo pipefail

GITHUB_TOKEN="${GITHUB_TOKEN:?Error: GITHUB_TOKEN is required}"
GITHUB_USER="${GITHUB_USER:?Error: GITHUB_USER is required}"
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

# --- Fetch All Repos ---------------------------------------------------------
fetch_repos() {
    local page=1
    local all_repos=""

    while true; do
        local response
        response=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" \
            "${GITHUB_API}/user/repos?per_page=100&page=${page}&affiliation=owner")

        local names
        names=$(echo "${response}" | jq -r '.[].name // empty' 2>/dev/null)

        [[ -z "${names}" ]] && break

        all_repos="${all_repos}${all_repos:+$'\n'}${names}"
        page=$((page + 1))
    done

    echo "${all_repos}"
}

# --- Setup Runner Instance Per Repo ------------------------------------------
setup_runner_instance() {
    local instance="$1"
    local repo="$2"
    local runner_name="homelab-101-${instance}"
    local runner_dir="${RUNNER_BASE}/instance-${instance}/${repo}"
    local tarball="actions-runner-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz"
    local service_name="github-runner-${instance}-${repo}"

    log "Setting up instance ${instance} for ${GITHUB_USER}/${repo} (runner: ${runner_name})..."

    # Create runner directory
    sudo -u "${RUNNER_USER}" mkdir -p "${runner_dir}"

    # Extract runner (use cached tarball)
    if [[ ! -f "${runner_dir}/run.sh" ]]; then
        sudo -u "${RUNNER_USER}" tar xzf "/tmp/${tarball}" -C "${runner_dir}" 2>/dev/null
    fi

    # Get registration token
    local token
    token=$(curl -s -X POST \
        -H "Authorization: token ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        "${GITHUB_API}/repos/${GITHUB_USER}/${repo}/actions/runners/registration-token" | jq -r '.token // empty')

    if [[ -z "${token}" ]]; then
        warn "Failed to get token for ${repo} (instance ${instance}). Skipping."
        return 1
    fi

    # Configure runner
    sudo -u "${RUNNER_USER}" bash -c "
        cd '${runner_dir}' && \
        ./config.sh \
            --url 'https://github.com/${GITHUB_USER}/${repo}' \
            --token '${token}' \
            --name '${runner_name}' \
            --labels '${RUNNER_LABELS}' \
            --work '${runner_dir}/_work' \
            --replace \
            --unattended
    " 2>&1 || {
        warn "Failed to register instance ${instance} for ${repo}. Skipping."
        return 1
    }

    # Create systemd service
    cat > "/etc/systemd/system/${service_name}.service" <<EOF
[Unit]
Description=GitHub Actions Runner - instance ${instance} - ${repo}
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
    log "=== Bulk Runner Registration ==="
    log "User: ${GITHUB_USER}"
    log "Instances per repo: ${RUNNER_COUNT}"
    log ""

    # Download runner tarball once
    local tarball="actions-runner-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz"
    if [[ ! -f "/tmp/${tarball}" ]]; then
        log "Downloading runner v${RUNNER_VERSION}..."
        curl -sL "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${tarball}" -o "/tmp/${tarball}"
    fi

    sudo -u "${RUNNER_USER}" mkdir -p "${RUNNER_BASE}"

    local repos
    repos=$(fetch_repos)

    if [[ -z "${repos}" ]]; then
        err "No repos found for ${GITHUB_USER}."
        exit 1
    fi

    local total=0
    local success=0
    local failed=0

    for i in $(seq 1 "${RUNNER_COUNT}"); do
        log ""
        log "--- Instance ${i} of ${RUNNER_COUNT} ---"

        while IFS= read -r repo; do
            [[ -z "${repo}" ]] && continue
            total=$((total + 1))

            if setup_runner_instance "${i}" "${repo}"; then
                success=$((success + 1))
            else
                failed=$((failed + 1))
            fi
        done <<< "${repos}"
    done

    log ""
    log "=== Registration Complete ==="
    log "Total: ${total} | Success: ${success} | Failed: ${failed}"
    log ""
    log "Manage runners:"
    log "  systemctl list-units 'github-runner-*'"
    log "  systemctl status github-runner-<instance>-<repo>"
    log "  journalctl -u github-runner-<instance>-<repo> -f"
}

main "$@"
