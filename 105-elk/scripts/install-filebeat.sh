#!/bin/bash
set -euo pipefail

FILEBEAT_VERSION="8.12.0"
ELK_HOST="192.168.50.105"
LOGSTASH_PORT="5044"

echo "=== Filebeat Installation Script ==="
echo "Target: Logstash at ${ELK_HOST}:${LOGSTASH_PORT}"

FORCE_REINSTALL="${1:-}"
if command -v filebeat &> /dev/null; then
    echo "Filebeat already installed: $(filebeat version)"
    if [[ "$FORCE_REINSTALL" != "--force" ]]; then
        echo "Use --force to reinstall"
        exit 0
    fi
    echo "Reinstalling..."
fi

ARCH=$(dpkg --print-architecture 2>/dev/null || echo "amd64")
DEB_FILE="filebeat-${FILEBEAT_VERSION}-${ARCH}.deb"
DOWNLOAD_URL="https://artifacts.elastic.co/downloads/beats/filebeat/${DEB_FILE}"

echo "Downloading Filebeat ${FILEBEAT_VERSION}..."
curl -L -O "${DOWNLOAD_URL}"

echo "Installing Filebeat..."
dpkg -i "${DEB_FILE}"
rm -f "${DEB_FILE}"

SERVICE_NAME=$(hostname -s)

echo "Configuring Filebeat..."
tee /etc/filebeat/filebeat.yml > /dev/null <<EOF
filebeat.inputs:
  - type: log
    enabled: true
    paths:
      - /var/log/*.log
      - /var/log/syslog
    fields:
      service: system
      host: ${SERVICE_NAME}
    fields_under_root: true

  - type: container
    enabled: true
    paths:
      - /var/lib/docker/containers/*/*.log
    processors:
      - add_docker_metadata:
          host: "unix:///var/run/docker.sock"

output.logstash:
  hosts: ["${ELK_HOST}:${LOGSTASH_PORT}"]

processors:
  - add_host_metadata:
      when.not.contains.tags: forwarded

logging.level: info
logging.to_files: true
logging.files:
  path: /var/log/filebeat
  name: filebeat
  keepfiles: 7
EOF

echo "Enabling and starting Filebeat..."
systemctl daemon-reload
systemctl enable filebeat
systemctl restart filebeat

echo "Verifying Filebeat status..."
systemctl status filebeat --no-pager

echo ""
echo "=== Installation Complete ==="
echo "Logs shipping to: ${ELK_HOST}:${LOGSTASH_PORT}"
echo "Check logs: journalctl -u filebeat -f"
