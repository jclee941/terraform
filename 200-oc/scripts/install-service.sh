#!/bin/bash
# install-service.sh - Install OpenCode systemd service files
# Usage: sudo ./install-service.sh [--enable] [--start]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/../config/systemd"
SYSTEMD_DIR="/etc/systemd/system"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Check root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    exit 1
fi

# Parse arguments
ENABLE_SERVICE=false
START_SERVICE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --enable) ENABLE_SERVICE=true ;;
        --start)  START_SERVICE=true ;;
        --help)
            echo "Usage: $0 [--enable] [--start]"
            echo "  --enable  Enable services on boot"
            echo "  --start   Start services after installation"
            exit 0
            ;;
        *) log_error "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

# Validate config directory
if [[ ! -d "$CONFIG_DIR" ]]; then
    log_error "Config directory not found: $CONFIG_DIR"
    exit 1
fi

# Install service files
log_info "Installing systemd service files..."

UNITS=(
    "opencode.service"
    "opencode.socket"
    "opencode-cleanup.service"
    "opencode-cleanup.timer"
)

for unit in "${UNITS[@]}"; do
    src="${CONFIG_DIR}/${unit}"
    dst="${SYSTEMD_DIR}/${unit}"
    
    if [[ -f "$src" ]]; then
        cp -v "$src" "$dst"
        chmod 644 "$dst"
        log_info "Installed: $unit"
    else
        log_warn "Skipped (not found): $unit"
    fi
done

# Create runtime directory
mkdir -p /run/opencode
chown jclee:jclee /run/opencode

# Reload systemd
log_info "Reloading systemd daemon..."
systemctl daemon-reload

# Enable services
if [[ "$ENABLE_SERVICE" == true ]]; then
    log_info "Enabling services..."
    systemctl enable opencode.service
    systemctl enable opencode-cleanup.timer
fi

# Start services
if [[ "$START_SERVICE" == true ]]; then
    log_info "Starting services..."
    systemctl start opencode.service
    systemctl start opencode-cleanup.timer
fi

log_info "Installation complete!"
echo ""
echo "Commands:"
echo "  systemctl status opencode"
echo "  journalctl -u opencode -f"
echo "  systemctl start opencode"
