#!/usr/bin/env bash
# =============================================================================
# GitHub Actions Self-hosted Runner Setup Script
# =============================================================================
# Installs and configures GitHub Actions runner on LXC container (VMID 101).
# Registers runner to all user repos for shared CI/CD.
#
# Prerequisites:
#   - LXC container running Debian 12 (created by Terraform)
#
# Usage:
#   ./setup-runner.sh
#   GITHUB_USER="myuser" ./setup-runner.sh
# =============================================================================

set -euo pipefail

# --- Configuration -----------------------------------------------------------
RUNNER_VERSION="${RUNNER_VERSION:-2.322.0}"
RUNNER_ARCH="${RUNNER_ARCH:-linux-x64}"
RUNNER_USER="runner"
RUNNER_HOME="/home/${RUNNER_USER}"
RUNNER_DIR="${RUNNER_HOME}/actions-runner"
RUNNER_LABELS="self-hosted,linux,x64,homelab"

GITHUB_USER="${GITHUB_USER:-runner}"

# --- Colors ------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[-]${NC} $*" >&2; }

# --- Phase 1: System Dependencies -------------------------------------------
install_dependencies() {
    log "Installing system dependencies..."
    apt-get update -qq
    apt-get install -y -qq \
        curl \
        jq \
        git \
        sudo \
        ca-certificates \
        gnupg \
        lsb-release \
        build-essential \
        libssl-dev \
        libffi-dev \
        python3 \
        python3-pip \
        unzip \
        zip \
        wget \
        apt-transport-https \
        software-properties-common \
        >/dev/null 2>&1
    log "System dependencies installed."
}

# --- Phase 2: Docker Installation (for container-based jobs) -----------------
install_docker() {
    if command -v docker &>/dev/null; then
        log "Docker already installed: $(docker --version)"
        return
    fi

    log "Installing Docker..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1

    systemctl enable docker
    systemctl start docker
    log "Docker installed: $(docker --version)"
}

# --- Phase 3: Create Runner User --------------------------------------------
create_runner_user() {
    if id "${RUNNER_USER}" &>/dev/null; then
        log "Runner user '${RUNNER_USER}' already exists."
    else
        log "Creating runner user '${RUNNER_USER}'..."
        useradd -m -s /bin/bash "${RUNNER_USER}"
        usermod -aG sudo "${RUNNER_USER}"
        echo "${RUNNER_USER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${RUNNER_USER}"
    fi

    # Add to docker group
    if getent group docker &>/dev/null; then
        usermod -aG docker "${RUNNER_USER}"
    fi
}

# --- Phase 4: Install GitHub Actions Runner ----------------------------------
install_runner() {
    log "Installing GitHub Actions Runner v${RUNNER_VERSION}..."

    local tarball="actions-runner-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz"
    local url="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${tarball}"

    sudo -u "${RUNNER_USER}" mkdir -p "${RUNNER_DIR}"

    if [[ ! -f "${RUNNER_DIR}/.runner" ]]; then
        curl -sL "${url}" -o "/tmp/${tarball}"
        sudo -u "${RUNNER_USER}" tar xzf "/tmp/${tarball}" -C "${RUNNER_DIR}"
        rm -f "/tmp/${tarball}"
        log "Runner binary extracted to ${RUNNER_DIR}"
    else
        log "Runner already installed at ${RUNNER_DIR}"
    fi

    # Install runner dependencies
    "${RUNNER_DIR}/bin/installdependencies.sh" >/dev/null 2>&1 || true
}

# --- Phase 5: Done (Registration via register-all-repos.sh) ------------------
# Runner registration is handled separately by register-all-repos.sh
# This keeps setup idempotent and registration decoupled.

# --- Phase 6: Systemd Service (template only) --------------------------------
install_service() {
    log "Installing runner service template..."

    cat > /etc/systemd/system/github-runner@.service <<EOF
[Unit]
Description=GitHub Actions Runner - %i
After=network.target docker.service
Wants=docker.service

[Service]
Type=simple
User=${RUNNER_USER}
Group=${RUNNER_USER}
WorkingDirectory=/home/${RUNNER_USER}/runners/%i
ExecStart=/home/${RUNNER_USER}/runners/%i/run.sh
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
    log "Systemd template service installed: github-runner@<repo>.service"
}

# --- Phase 7: Summary --------------------------------------------------------
register_all_repos() {
    log "Skipping registration (use register-all-repos.sh separately)."
    log "Available repos will each get their own runner instance."
}

# --- Main --------------------------------------------------------------------
main() {
    log "=== GitHub Actions Runner Setup ==="
    log "Target: VMID 101 (192.168.50.101)"
    log "User: ${GITHUB_USER}"
    log ""

    install_dependencies
    if [[ "${SKIP_DOCKER:-0}" != "1" ]]; then
        install_docker
    else
        warn "Skipping Docker install (SKIP_DOCKER=1, unprivileged LXC)"
    fi
    create_runner_user
    install_runner
    install_service

    log ""
    log "=== Setup Complete ==="
    log "Next: Run register-all-repos.sh to register runner to all repos"
    log ""
}

main "$@"
