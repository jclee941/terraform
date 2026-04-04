#!/bin/bash
# GitLab Runner Emergency Recovery Script
# Run this on LXC 101 (192.168.50.101) to fix runner issues

set -e

echo "=========================================="
echo "GitLab Runner Recovery Script"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
  echo -e "${GREEN}[+]${NC} $1"
}

warn() {
  echo -e "${YELLOW}[!]${NC} $1"
}

error() {
  echo -e "${RED}[-]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  error "This script must be run as root"
  exit 1
fi

# Step 1: Check current status
echo ""
echo "Step 1: Checking current runner status..."
echo "=========================================="

if command -v gitlab-runner &>/dev/null; then
  log "GitLab Runner binary found"
  gitlab-runner --version 2>&1 | head -3
else
  warn "GitLab Runner not installed"
fi

if [ -f /opt/gitlab-runner/config.toml ]; then
  log "Runner config exists: /opt/gitlab-runner/config.toml"
  echo "Registered runners:"
  gitlab-runner list 2>&1 || warn "Failed to list runners"
else
  warn "No runner config found"
fi

if systemctl is-active --quiet gitlab-runner 2>/dev/null; then
  log "GitLab Runner service is ACTIVE"
  systemctl status gitlab-runner --no-pager 2>&1 | head -10
else
  warn "GitLab Runner service is NOT running"
fi

# Step 2: Check system resources
echo ""
echo ""
echo "Step 2: System Resources"
echo "=========================================="

log "Memory usage:"
free -h

echo ""
log "Disk usage:"
df -h /opt /usr/local/bin 2>/dev/null | head -5

echo ""
log "CPU load:"
uptime

# Step 3: Stop existing runner if running
echo ""
echo ""
echo "Step 3: Stopping existing runner..."
echo "=========================================="

if systemctl is-active --quiet gitlab-runner 2>/dev/null; then
  warn "Stopping gitlab-runner service..."
  systemctl stop gitlab-runner 2>&1 || true
  systemctl disable gitlab-runner 2>&1 || true
  log "Runner stopped"
else
  log "Runner service not running"
fi

# Kill any hanging processes
pkill -f gitlab-runner 2>/dev/null || true
sleep 2

# Step 4: Install/Update GitLab Runner
echo ""
echo ""
echo "Step 4: Installing GitLab Runner..."
echo "=========================================="

RUNNER_VERSION="17.8.0"
RUNNER_ARCH="linux-amd64"
BINARY_PATH="/usr/local/bin/gitlab-runner"

if [ -f "$BINARY_PATH" ]; then
  log "GitLab Runner already exists, checking version..."
  gitlab-runner --version 2>&1 | head -1
  read -p "Reinstall? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Skipping installation"
  else
    rm -f "$BINARY_PATH"
  fi
fi

if [ ! -f "$BINARY_PATH" ]; then
  log "Downloading GitLab Runner v${RUNNER_VERSION}..."
  curl -sL "https://gitlab-runner-downloads.s3.amazonaws.com/v${RUNNER_VERSION}/binaries/gitlab-runner-${RUNNER_ARCH}" -o "$BINARY_PATH"
  chmod +x "$BINARY_PATH"
  log "GitLab Runner installed successfully"
fi

# Step 5: Setup directories and user
echo ""
echo ""
echo "Step 5: Setting up directories..."
echo "=========================================="

RUNNER_USER="gitlab-runner"
RUNNER_DIR="/opt/gitlab-runner"

# Create user if not exists
if id "$RUNNER_USER" &>/dev/null; then
  log "User $RUNNER_USER already exists"
else
  log "Creating user: $RUNNER_USER"
  useradd -m -s /bin/bash "$RUNNER_USER"
fi

# Add to docker group
usermod -aG docker "$RUNNER_USER" 2>/dev/null || warn "Docker group not found, skipping"

# Create runner directory
mkdir -p "$RUNNER_DIR"
chown "$RUNNER_USER:$RUNNER_USER" "$RUNNER_DIR"
log "Directory setup complete: $RUNNER_DIR"

# Step 6: Register runner
echo ""
echo ""
echo "Step 6: Registering Runner"
echo "=========================================="

CONFIG_FILE="${RUNNER_DIR}/config.toml"

if [ -f "$CONFIG_FILE" ]; then
  warn "Existing config found"
  read -p "Re-register runner? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Keeping existing config"
  else
    rm -f "$CONFIG_FILE"
  fi
fi

if [ ! -f "$CONFIG_FILE" ]; then
  echo ""
  echo "GitLab Runner Registration"
  echo "--------------------------"

  # Check if token is provided via environment
  if [ -z "$GITLAB_RUNNER_TOKEN" ]; then
    echo -n "Enter GitLab Runner Token (or set GITLAB_RUNNER_TOKEN env var): "
    read -s GITLAB_RUNNER_TOKEN
    echo
  fi

  if [ -z "$GITLAB_RUNNER_TOKEN" ]; then
    error "No token provided. Registration skipped."
    echo "To register later, run:"
    echo "  export GITLAB_RUNNER_TOKEN=<your-token>"
    echo "  gitlab-runner register --non-interactive ..."
  else
    log "Registering runner..."

    gitlab-runner register \
      --non-interactive \
      --url "http://gitlab.jclee.me" \
      --registration-token "$GITLAB_RUNNER_TOKEN" \
      --executor docker \
      --docker-image alpine:latest \
      --name "homelab-101" \
      --tag-list "homelab,docker,linux,terraform" \
      --run-untagged="false" \
      --locked="false" \
      --access-level="not_protected" \
      --config "$CONFIG_FILE" \
      --docker-memory "512m" \
      --docker-cpus "1.5" 2>&1

    if [ $? -eq 0 ]; then
      log "Runner registered successfully!"

      # Update concurrent setting
      if ! grep -q "^concurrent" "$CONFIG_FILE"; then
        sed -i "1s/^/concurrent = 8\n\n/" "$CONFIG_FILE"
        log "Updated concurrent = 8"
      fi
    else
      error "Registration failed"
      exit 1
    fi
  fi
else
  log "Using existing config: $CONFIG_FILE"
fi

# Step 7: Create systemd service
echo ""
echo ""
echo "Step 7: Creating systemd service..."
echo "=========================================="

SERVICE_FILE="/etc/systemd/system/gitlab-runner.service"

cat >"$SERVICE_FILE" <<EOF
[Unit]
Description=GitLab Runner
After=syslog.target network.target

[Service]
Type=simple
User=gitlab-runner
ExecStart=/usr/local/bin/gitlab-runner run --config /opt/gitlab-runner/config.toml
Restart=always
RestartSec=10
StandardOutput=append:/var/log/gitlab-runner.log
StandardError=append:/var/log/gitlab-runner.log

[Install]
WantedBy=multi-user.target
EOF

log "Service file created: $SERVICE_FILE"

# Reload and start service
systemctl daemon-reload
systemctl enable gitlab-runner

if [ -f "$CONFIG_FILE" ]; then
  log "Starting gitlab-runner service..."
  systemctl start gitlab-runner
  sleep 3

  if systemctl is-active --quiet gitlab-runner; then
    log "✓ Service started successfully!"
  else
    error "✗ Service failed to start"
    systemctl status gitlab-runner --no-pager
    exit 1
  fi
else
  warn "No config file, service not started"
  echo "Start manually after registration:"
  echo "  systemctl start gitlab-runner"
fi

# Step 8: Final verification
echo ""
echo ""
echo "Step 8: Final Verification"
echo "=========================================="

if systemctl is-active --quiet gitlab-runner; then
  log "✓ GitLab Runner is RUNNING"
  echo ""
  gitlab-runner list 2>&1 || true
else
  warn "✗ GitLab Runner is NOT running"
fi

echo ""
echo "=========================================="
echo "Recovery Complete!"
echo "=========================================="
echo ""
echo "Useful commands:"
echo "  gitlab-runner list        - List registered runners"
echo "  gitlab-runner verify      - Verify runner token"
echo "  journalctl -u gitlab-runner -f  - View logs"
echo "  systemctl status gitlab-runner    - Check service status"
echo ""

if ! systemctl is-active --quiet gitlab-runner; then
  echo "⚠️  WARNING: Runner is not running!"
  echo "   Check logs: journalctl -u gitlab-runner -n 50"
fi
