#!/bin/bash
# uninstall-service.sh - Remove OpenCode systemd service files
# Usage: sudo ./uninstall-service.sh

set -euo pipefail

SYSTEMD_DIR="/etc/systemd/system"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    exit 1
fi

UNITS=(
    "opencode.service"
    "opencode.socket"
    "opencode-cleanup.service"
    "opencode-cleanup.timer"
)

# Stop and disable services
log_info "Stopping services..."
for unit in "${UNITS[@]}"; do
    systemctl stop "$unit" 2>/dev/null || true
    systemctl disable "$unit" 2>/dev/null || true
done

# Remove service files
log_info "Removing service files..."
for unit in "${UNITS[@]}"; do
    rm -fv "${SYSTEMD_DIR}/${unit}"
done

# Cleanup runtime directory
rm -rf /run/opencode

# Reload systemd
systemctl daemon-reload

log_info "Uninstallation complete!"
