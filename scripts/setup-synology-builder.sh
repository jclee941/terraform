#!/bin/bash
# Docker Buildx Builder Setup for Synology NAS
# This script sets up SSH config and creates a Docker Buildx builder for Synology

set -e

echo "=== Docker Buildx Builder Setup for Synology ==="
echo ""

# Step 1: Check SSH connectivity
echo "1. Testing SSH connectivity to Synology..."
if ! ssh -o ConnectTimeout=5 jclee@192.168.50.215 "echo 'SSH OK'" 2>/dev/null; then
  echo "   ERROR: Cannot connect to Synology via SSH"
  echo "   Please ensure:"
  echo "   - SSH is enabled on Synology (Control Panel > Terminal & SNMP)"
  echo "   - SSH key is set up: ssh-copy-id jclee@192.168.50.215"
  exit 1
fi
echo "   ✓ SSH connection successful"
echo ""

# Step 2: Find Docker path on Synology
echo "2. Finding Docker installation on Synology..."
DOCKER_PATH=$(ssh jclee@192.168.50.215 "find /var/packages/ContainerManager -name docker -type f 2>/dev/null | head -1" 2>/dev/null || true)

if [ -z "$DOCKER_PATH" ]; then
  echo "   WARNING: Docker path not found in ContainerManager"
  echo "   Trying alternative paths..."
  DOCKER_PATH=$(ssh jclee@192.168.50.215 "which docker 2>/dev/null || ls /usr/bin/docker 2>/dev/null || ls /usr/local/bin/docker 2>/dev/null" | head -1 || true)
fi

if [ -n "$DOCKER_PATH" ]; then
  echo "   ✓ Docker found at: $DOCKER_PATH"
else
  echo "   WARNING: Docker path not auto-detected"
  DOCKER_PATH="/var/packages/ContainerManager/target/usr/bin/docker"
  echo "   Using default: $DOCKER_PATH"
fi
echo ""

# Step 3: Create SSH config entry
echo "3. Setting up SSH config..."
SSH_CONFIG="$HOME/.ssh/config"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# Backup existing config
if [ -f "$SSH_CONFIG" ]; then
  cp "$SSH_CONFIG" "$SSH_CONFIG.backup.$(date +%Y%m%d-%H%M%S)"
fi

# Add Synology entry if not exists
if ! grep -q "Host synology-builder" "$SSH_CONFIG" 2>/dev/null; then
  cat >>"$SSH_CONFIG" <<EOF

# Synology Docker Builder
Host synology-builder
    HostName 192.168.50.215
    User jclee
    StrictHostKeyChecking accept-new
    ConnectTimeout 30
    ServerAliveInterval 60
EOF
  echo "   ✓ SSH config entry added"
else
  echo "   ✓ SSH config entry already exists"
fi
echo ""

# Step 4: Create Docker context if not exists
echo "4. Creating Docker context..."
if ! docker context ls | grep -q "synology"; then
  docker context create synology --docker "host=ssh://synology-builder"
  echo "   ✓ Docker context 'synology' created"
else
  echo "   ✓ Docker context 'synology' already exists"
fi
echo ""

# Step 5: Create Buildx builder
echo "5. Creating Buildx builder..."
if docker buildx ls | grep -q "synology-builder"; then
  echo "   Removing existing builder..."
  docker buildx rm synology-builder 2>/dev/null || true
fi

# Try to create builder with Docker context
echo "   Attempting to create builder using Docker context..."
if docker buildx create \
  --name synology-builder \
  --driver docker-container \
  --node synology-node \
  synology \
  --use 2>/dev/null; then
  echo "   ✓ Buildx builder created using Docker context"
else
  echo "   WARNING: Could not create builder with context"
  echo ""
  echo "   Alternative: Direct SSH builder (may fail due to Docker path)..."

  # Try with explicit driver options
  if docker buildx create \
    --name synology-builder \
    --driver remote \
    --node synology-node \
    tcp://192.168.50.215:2375 \
    --use 2>/dev/null; then
    echo "   ✓ Buildx builder created with remote driver"
  else
    echo "   ERROR: Could not create Buildx builder automatically"
    echo ""
    echo "   Manual setup required on Synology:"
    echo "   1. Enable Docker TCP port:"
    echo "      - SSH to Synology: ssh jclee@192.168.50.215"
    echo "      - Edit: sudo vim /var/packages/ContainerManager/etc/dockerd.json"
    echo "      - Add: {\"hosts\": [\"unix:///var/run/docker.sock\", \"tcp://0.0.0.0:2375\"]}"
    echo "      - Restart: sudo /var/packages/ContainerManager/scripts/start-stop-status restart"
    echo ""
    echo "   2. Then run: docker buildx create --name synology-builder --driver remote tcp://192.168.50.215:2375 --use"
    exit 1
  fi
fi
echo ""

# Step 6: Verify builder
echo "6. Verifying builder..."
if docker buildx inspect synology-builder --bootstrap 2>/dev/null; then
  echo "   ✓ Builder is active and ready"
  echo ""
  echo "=== Setup Complete ==="
  echo ""
  echo "Usage:"
  echo "  docker buildx use synology-builder"
  echo "  docker buildx build --platform linux/amd64 -t myimage:latest ."
  echo ""
  echo "To switch back to local:"
  echo "  docker buildx use default"
else
  echo "   WARNING: Builder created but may need bootstrap"
  echo "   Run: docker buildx inspect synology-builder --bootstrap"
fi
