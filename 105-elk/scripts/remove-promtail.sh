#!/bin/bash
set -euo pipefail

echo "=== Promtail Removal Script ==="
echo "This will remove Promtail and its configurations."

if ! command -v promtail &> /dev/null && ! systemctl is-active promtail &> /dev/null 2>&1; then
    echo "Promtail not found. Skipping."
    exit 0
fi

echo "Stopping Promtail service..."
sudo systemctl stop promtail 2>/dev/null || true
sudo systemctl disable promtail 2>/dev/null || true

echo "Removing Promtail binary and config..."
sudo rm -f /usr/local/bin/promtail
sudo rm -f /usr/bin/promtail
sudo rm -rf /etc/promtail
sudo rm -f /etc/systemd/system/promtail.service

echo "Cleaning up logs..."
sudo rm -rf /var/log/promtail

echo "Reloading systemd..."
sudo systemctl daemon-reload

echo ""
echo "=== Promtail Removed ==="
echo "Install Filebeat: /opt/elk/scripts/install-filebeat.sh"
