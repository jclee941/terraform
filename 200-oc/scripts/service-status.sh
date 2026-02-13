#!/bin/bash
# service-status.sh - Check OpenCode service status
# Usage: ./service-status.sh

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

header() { echo -e "\n${CYAN}=== $* ===${NC}"; }

UNITS=(
    "opencode.service"
    "opencode.socket"
    "opencode-cleanup.timer"
)

header "Service Status"
for unit in "${UNITS[@]}"; do
    STATUS=$(systemctl is-active "$unit" 2>/dev/null || echo "inactive")
    ENABLED=$(systemctl is-enabled "$unit" 2>/dev/null || echo "disabled")
    
    case $STATUS in
        active)   STATUS_COLOR="${GREEN}${STATUS}${NC}" ;;
        inactive) STATUS_COLOR="${YELLOW}${STATUS}${NC}" ;;
        *)        STATUS_COLOR="${RED}${STATUS}${NC}" ;;
    esac
    
    printf "%-30s %b  (enabled: %s)\n" "$unit" "$STATUS_COLOR" "$ENABLED"
done

header "Resource Usage"
if systemctl is-active opencode.service &>/dev/null; then
    systemctl show opencode.service --property=MemoryCurrent,CPUUsageNSec 2>/dev/null | \
        sed 's/MemoryCurrent=/Memory: /; s/CPUUsageNSec=/CPU Time: /'
else
    echo "Service not running"
fi

header "Recent Logs (last 10 lines)"
journalctl -u opencode.service -n 10 --no-pager 2>/dev/null || echo "No logs available"

header "Log Directory"
LOG_DIR="${HOME}/.local/share/opencode/log"
if [[ -d "$LOG_DIR" ]]; then
    du -sh "$LOG_DIR"
    find "$LOG_DIR" -name "*.log" | wc -l | xargs -I{} echo "{} log files"
else
    echo "Log directory not found"
fi
