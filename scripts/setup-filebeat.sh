#!/bin/bash
# setup-filebeat.sh - Idempotent Filebeat 8.12.0 installation script
#
# Installs and enables Filebeat 8.12.0 via official Elastic APT repository.
# Supports Debian 12 (bookworm) and Ubuntu 24.04 (noble).
#
# Constraints:
# - Matches ES version 8.12.0
# - Enables but does not start if config is missing
# - Configures docker group access for log harvesting

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

FILEBEAT_VERSION="8.12.0"

# Helper for timestamps
log() {
    local level=$1
    local msg=$2
    local color=$3
    echo -e "${color}[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $msg${NC}"
}

ok() { log "OK" "$1" "$GREEN"; }
info() { log "INFO" "$1" "$BLUE"; }
warn() { log "WARN" "$1" "$YELLOW"; }
err() { log "FAIL" "$1" "$RED"; }
skip() { log "SKIP" "$1" "$YELLOW"; }

# Verify running as root
if [[ $EUID -ne 0 ]]; then
   err "This script must be run as root"
   exit 1
fi

info "Starting Filebeat $FILEBEAT_VERSION installation..."

# OS Detection
CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
OS_ID=$(. /etc/os-release && echo "$ID")

info "Detected OS: $OS_ID $CODENAME"

# Check if already installed at correct version
if command -v filebeat &> /dev/null; then
    CURRENT_VERSION=$(filebeat version | awk '{print $3}')
    if [[ "$CURRENT_VERSION" == "$FILEBEAT_VERSION" ]]; then
        skip "Filebeat $FILEBEAT_VERSION is already installed"
    else
        warn "Filebeat version mismatch: found $CURRENT_VERSION, expected $FILEBEAT_VERSION"
        # We will proceed to install the pinned version
    fi
else
    info "Filebeat not found. Proceeding with installation."
fi

# Install dependencies
info "Installing dependencies (gnupg, apt-transport-https, curl)..."
apt-get update -qq
apt-get install -y -qq gnupg apt-transport-https curl > /dev/null

# Add Elastic GPG Key
if [ ! -f /usr/share/keyrings/elasticsearch-keyring.gpg ]; then
    info "Adding Elastic GPG key..."
    curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
else
    skip "Elastic GPG key already exists"
fi

# Add Elastic Repository
REPO_FILE="/etc/apt/sources.list.d/elastic-8.x.list"
if [ ! -f "$REPO_FILE" ]; then
    info "Adding Elastic 8.x repository..."
    echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | tee "$REPO_FILE" > /dev/null
else
    skip "Elastic 8.x repository already configured"
fi

# Install Filebeat
info "Installing Filebeat $FILEBEAT_VERSION..."
apt-get update -qq
# Use --allow-downgrades in case a newer version was somehow installed
apt-get install -y -qq --allow-downgrades "filebeat=$FILEBEAT_VERSION" > /dev/null

if [[ $? -eq 0 ]]; then
    ok "Filebeat $FILEBEAT_VERSION installed successfully"
else
    err "Failed to install Filebeat"
    exit 1
fi

# Configure permissions for Docker log harvesting
if getent group docker > /dev/null; then
    info "Adding filebeat user to docker group..."
    usermod -aG docker filebeat
    ok "Permissions configured for /var/lib/docker/containers"
else
    warn "Docker group not found. Skipping group assignment."
fi

# Enable and handle service startup
info "Enabling Filebeat systemd service..."
systemctl enable filebeat > /dev/null

if [ -f /etc/filebeat/filebeat.yml ]; then
    info "Configuration found at /etc/filebeat/filebeat.yml. Starting service..."
    systemctl restart filebeat
    ok "Filebeat service started"
else
    warn "Configuration NOT found at /etc/filebeat/filebeat.yml. Service will NOT be started."
    info "Please deploy configuration before starting the service."
fi

ok "Filebeat setup completed successfully"
