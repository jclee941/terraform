#!/usr/bin/env bash
# install-filebeat.sh — Remote execution payload for Terraform provisioners.
#
# EXCEPTION NOTICE: This shell script is intentionally retained as-is per monorepo
# standards exception. It is SCP'd to target LXC/VM hosts and executed via
# remote-exec provisioner. Target hosts are minimal Debian containers without
# Go runtime, making Go binary deployment impractical.
#
# The canonical Go version exists at scripts/setup-filebeat.go for local
# tooling, but this script serves a different execution context.
#
# Per AGENTS.md and monorepo-standards.md, operational scripts must be Go,
# but remote execution payloads are exempt when target hosts lack Go runtime.
#
# Usage (via Terraform provisioner only):
#   sudo bash /tmp/install-filebeat.sh
#
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

FILEBEAT_VERSION="8.12.0"
KEYRING_PATH="/usr/share/keyrings/elasticsearch-keyring.gpg"
REPO_FILE="/etc/apt/sources.list.d/elastic-8.x.list"
REPO_LINE="deb [signed-by=${KEYRING_PATH}] https://artifacts.elastic.co/packages/8.x/apt stable main"
CONFIG_PATH="/etc/filebeat/filebeat.yml"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
log_info() { echo -e "${BLUE}[INFO] $*${NC}"; }
log_ok() { echo -e "${GREEN}[OK]   $*${NC}"; }
log_warn() { echo -e "${YELLOW}[WARN] $*${NC}"; }
log_fail() { echo -e "${RED}[FAIL] $*${NC}"; }
log_skip() { echo -e "${YELLOW}[SKIP] $*${NC}"; }

if [[ $EUID -ne 0 ]]; then
  log_fail "This script must be run as root"
  exit 1
fi

log_info "Starting Filebeat ${FILEBEAT_VERSION} installation..."

# Detect OS
OS_ID=$(. /etc/os-release && echo "$ID")
CODENAME=$(. /etc/os-release && echo "${VERSION_CODENAME:-unknown}")
log_info "Detected OS: ${OS_ID} ${CODENAME}"

# Check existing installation
if command -v filebeat &>/dev/null; then
  CURRENT_VERSION=$(filebeat version | awk '{print $3}')
  if [[ "$CURRENT_VERSION" == "$FILEBEAT_VERSION" ]]; then
    log_skip "Filebeat ${FILEBEAT_VERSION} is already installed"
  else
    log_warn "Filebeat version mismatch: found ${CURRENT_VERSION}, expected ${FILEBEAT_VERSION}"
  fi
else
  log_info "Filebeat not found. Proceeding with installation."
fi

# Install dependencies
log_info "Installing dependencies (gnupg, apt-transport-https, curl)..."
apt-get update -qq
apt-get install -y -qq gnupg apt-transport-https curl

# Add Elastic GPG key
if [[ -f "$KEYRING_PATH" ]]; then
  log_skip "Elastic GPG key already exists"
else
  log_info "Adding Elastic GPG key..."
  curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | gpg --dearmor -o "$KEYRING_PATH"
fi

# Add Elastic repository
if [[ -f "$REPO_FILE" ]]; then
  log_skip "Elastic 8.x repository already configured"
else
  log_info "Adding Elastic 8.x repository..."
  echo "$REPO_LINE" >"$REPO_FILE"
fi

# Install Filebeat
log_info "Installing Filebeat ${FILEBEAT_VERSION}..."
apt-get update -qq
apt-get install -y -qq --allow-downgrades -o Dpkg::Options::="--force-confold" "filebeat=${FILEBEAT_VERSION}"
log_ok "Filebeat ${FILEBEAT_VERSION} installed successfully"

# Docker group permissions
if getent group docker &>/dev/null; then
  log_info "Adding filebeat user to docker group..."
  usermod -aG docker filebeat
  log_ok "Permissions configured for /var/lib/docker/containers"
else
  log_warn "Docker group not found. Skipping group assignment."
fi

# Enable systemd service
log_info "Enabling Filebeat systemd service..."
systemctl enable filebeat

# Start if config exists
if [[ -f "$CONFIG_PATH" ]]; then
  log_info "Configuration found at ${CONFIG_PATH}. Starting service..."
  systemctl restart filebeat
  log_ok "Filebeat service started"
else
  log_warn "Configuration NOT found at ${CONFIG_PATH}. Service will NOT be started."
  log_info "Please deploy configuration before starting the service."
fi

log_ok "Filebeat setup completed successfully"
