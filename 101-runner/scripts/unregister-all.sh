#!/usr/bin/env bash
# =============================================================================
# Unregister All GitHub Actions Runners
# =============================================================================
# Cleanly removes all runner registrations and systemd services.
# Handles org-level runners (instance-N/) and legacy per-repo layouts
# (instance-N/repo/) for backward compatibility.
#
# Usage:
#   GITHUB_TOKEN="ghp_xxx" GITHUB_ORG="qws941-lab" ./unregister-all.sh
# =============================================================================

set -euo pipefail

GITHUB_TOKEN="${GITHUB_TOKEN:?Error: GITHUB_TOKEN is required}"
GITHUB_ORG="${GITHUB_ORG:?Error: GITHUB_ORG is required}"
GITHUB_API="https://api.github.com"

RUNNER_USER="runner"
RUNNER_BASE="/home/${RUNNER_USER}/runners"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[-]${NC} $*" >&2; }

log "=== Unregistering All Runners ==="

# --- Stop and disable all runner services -----------------------------------
for service in /etc/systemd/system/github-runner-*.service; do
    [[ -f "${service}" ]] || continue
    svc_name=$(basename "${service}" .service)
    log "Stopping ${svc_name}..."
    systemctl stop "${svc_name}" 2>/dev/null || true
    systemctl disable "${svc_name}" 2>/dev/null || true
    rm -f "${service}"
done

# Also handle legacy single runner service
systemctl stop github-runner.service 2>/dev/null || true
systemctl disable github-runner.service 2>/dev/null || true
rm -f /etc/systemd/system/github-runner.service

systemctl daemon-reload

# --- Get org-level removal token --------------------------------------------
get_org_remove_token() {
    curl -s -X POST \
        -H "Authorization: token ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        "${GITHUB_API}/orgs/${GITHUB_ORG}/actions/runners/remove-token" | jq -r '.token // empty' 2>/dev/null
}

# --- Unregister runners (instance-N/) ---------------------------------------
for instance_dir in "${RUNNER_BASE}"/instance-*/; do
    [[ -d "${instance_dir}" ]] || continue
    instance=$(basename "${instance_dir}")

    # Org-level runner (has .runner directly in instance dir)
    if [[ -f "${instance_dir}/.runner" ]]; then
        log "Removing org runner config for ${instance}..."

        token=$(get_org_remove_token)
        if [[ -n "${token}" ]]; then
            sudo -u "${RUNNER_USER}" bash -c "cd '${instance_dir}' && ./config.sh remove --token '${token}'" 2>/dev/null || true
        else
            warn "Failed to get org removal token for ${instance}. Directory cleaned anyway."
        fi
    else
        # Legacy per-repo layout (instance-N/repo/)
        log "Processing legacy layout ${instance}..."

        for runner_dir in "${instance_dir}"*/; do
            [[ -d "${runner_dir}" ]] || continue
            repo=$(basename "${runner_dir}")

            log "  Removing legacy runner config for ${repo} (${instance})..."

            token=$(get_org_remove_token)
            if [[ -n "${token}" ]]; then
                sudo -u "${RUNNER_USER}" bash -c "cd '${runner_dir}' && ./config.sh remove --token '${token}'" 2>/dev/null || true
            else
                warn "  Failed to get removal token for ${repo} (${instance}). Directory cleaned anyway."
            fi
        done
    fi
done

# --- Unregister legacy single-runner layout (runners/repo/) -----------------
for runner_dir in "${RUNNER_BASE}"/*/; do
    [[ -d "${runner_dir}" ]] || continue
    dir_name=$(basename "${runner_dir}")

    # Skip instance-* directories (already handled above)
    [[ "${dir_name}" == instance-* ]] && continue

    repo="${dir_name}"
    log "Removing legacy runner config for ${repo}..."

    token=$(get_org_remove_token)
    if [[ -n "${token}" ]]; then
        sudo -u "${RUNNER_USER}" bash -c "cd '${runner_dir}' && ./config.sh remove --token '${token}'" 2>/dev/null || true
    fi
done

# --- Clean up ----------------------------------------------------------------
rm -rf "${RUNNER_BASE}"
rm -rf "/home/${RUNNER_USER}/actions-runner"
rm -rf "/home/${RUNNER_USER}/_work"

log "All runners unregistered and cleaned up."
