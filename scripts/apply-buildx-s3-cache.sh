#!/bin/bash
# Live apply Docker Buildx S3 cache configuration to 200-oc and 220-youtube VMs
# Usage: ./scripts/apply-buildx-s3-cache.sh

set -euo pipefail

MINIO_ENDPOINT="http://192.168.50.215:9000"
MINIO_ACCESS_KEY="minioadmin"
MINIO_SECRET_KEY="minioadmin"
S3_REGION="us-east-1"
S3_BUCKET="buildx-cache"

VM200_IP="192.168.50.200"
VM220_IP="192.168.50.220"
SSH_USER="jclee"

echo "=== Applying Docker Buildx S3 cache to VMs ==="
echo "MinIO: $MINIO_ENDPOINT"
echo ""

apply_to_vm() {
  local ip=$1
  local name=$2

  echo "--- $name ($ip) ---"

  # Check SSH connectivity
  if ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${SSH_USER}@${ip}" "echo ok" >/dev/null 2>&1; then
    echo "ERROR: Cannot SSH to $name at $ip"
    return 1
  fi

  # Ensure qemu-guest-agent is running
  echo "Checking qemu-guest-agent..."
  ssh -o StrictHostKeyChecking=no "${SSH_USER}@${ip}" "
    sudo systemctl enable qemu-guest-agent 2>/dev/null || true
    sudo systemctl start qemu-guest-agent 2>/dev/null || true
    sudo systemctl status qemu-guest-agent --no-pager || echo 'qemu-guest-agent not installed'
  " || true

  # Apply Docker Buildx S3 cache
  echo "Setting up Docker Buildx S3 cache..."
  ssh -o StrictHostKeyChecking=no "${SSH_USER}@${ip}" "
    sudo mkdir -p /etc/docker/buildx

    # Create or update buildx builder with S3 cache
    sudo docker buildx create --name s3-cache --driver docker-container \
      --driver-opt env.BUILDKIT_S3_REGION=${S3_REGION} \
      --driver-opt env.BUILDKIT_S3_BUCKET=${S3_BUCKET} \
      --driver-opt env.BUILDKIT_S3_ENDPOINT=${MINIO_ENDPOINT} \
      --driver-opt env.BUILDKIT_S3_ACCESS_KEY_ID=${MINIO_ACCESS_KEY} \
      --driver-opt env.BUILDKIT_S3_SECRET_ACCESS_KEY=${MINIO_SECRET_KEY} \
      2>/dev/null || true

    # Make buildx the default for 'docker build'
    sudo docker buildx install || true

    sudo docker buildx use s3-cache || true
    sudo docker buildx inspect s3-cache --bootstrap || true

    # Write profile.d for persistent env vars
    sudo tee /etc/profile.d/docker-buildx-s3.sh > /dev/null <<'EOF'
# Docker Buildx S3 cache environment variables for MinIO
export BUILDKIT_S3_REGION=us-east-1
export BUILDKIT_S3_BUCKET=buildx-cache
export BUILDKIT_S3_ENDPOINT=http://192.168.50.215:9000
export BUILDKIT_S3_ACCESS_KEY_ID=minioadmin
export BUILDKIT_S3_SECRET_ACCESS_KEY=minioadmin
EOF

    sudo chmod 644 /etc/profile.d/docker-buildx-s3.sh

    # Create convenient alias for automatic cache usage
    sudo tee /etc/profile.d/docker-buildx-alias.sh > /dev/null <<'EOF'
# Automatic Docker Buildx S3 cache alias
alias docker-build-s3='docker buildx build --cache-to type=s3,region=us-east-1,bucket=buildx-cache,endpoint_url=http://192.168.50.215:9000,access_key_id=minioadmin,secret_access_key=minioadmin --cache-from type=s3,region=us-east-1,bucket=buildx-cache,endpoint_url=http://192.168.50.215:9000,access_key_id=minioadmin,secret_access_key=minioadmin'
EOF

    sudo chmod 644 /etc/profile.d/docker-buildx-alias.sh
  "

  echo "OK: $name configured"
  echo ""
}

apply_to_vm "$VM200_IP" "200-oc (jclee-dev)"
apply_to_vm "$VM220_IP" "220-youtube (youtube)"

echo "=== All VMs configured ==="
echo ""
echo "To use the cache in builds, run:"
echo '  docker buildx build --cache-to type=s3,region=us-east-1,bucket=buildx-cache,endpoint_url=http://192.168.50.215:9000,access_key_id=minioadmin,secret_access_key=minioadmin --cache-from type=s3,region=us-east-1,bucket=buildx-cache,endpoint_url=http://192.168.50.215:9000,access_key_id=minioadmin,secret_access_key=minioadmin .'
echo ""
echo "Or use the alias (after sourcing /etc/profile):"
echo '  docker-build-s3 -t myimage:latest .'
