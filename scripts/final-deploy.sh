#!/bin/bash
# Final deployment commands for GitLab Runner NFS cache

echo "=== GitLab Runner NFS Cache - Final Deployment ==="
echo ""

# Step 1: Check if NFS share exists
echo "[1/4] Checking NFS share on Synology..."
if ssh root@192.168.50.100 "showmount -e 192.168.50.215 | grep -q gitlab-runner-cache"; then
  echo "  ✅ NFS share exists"
else
  echo "  ⚠️  NFS share not found. Please create it:"
  echo "     ssh jclee@192.168.50.215"
  echo "     sudo synoshare --add gitlab-runner-cache 'GitLab Runner Cache' /volume1/gitlab-runner-cache"
  echo "     sudo synoshare --setnfs gitlab-runner-cache enable"
  echo "     sudo synonfsext --add-rule gitlab-runner-cache 192.168.50.0/24 rw"
  exit 1
fi

# Step 2: Run deployment script
echo "[2/4] Running deployment script on Proxmox..."
scp scripts/deploy-nfs-cache.sh root@192.168.50.100:/tmp/
ssh root@192.168.50.100 "bash /tmp/deploy-nfs-cache.sh"

# Step 3: Verify LXC mount
echo "[3/4] Verifying LXC mount..."
ssh root@192.168.50.100 "pct exec 101 -- df -h /srv/gitlab-runner/cache"

# Step 4: Setup GitLab Runner
echo "[4/4] Setting up GitLab Runner with cache..."
echo "  Run inside LXC 101:"
# Step 2: Run deployment script
echo "[2/4] Running deployment script on Proxmox..."
scp scripts/setup-nfs-cache-proxmox.go root@192.168.50.100:/tmp/
ssh root@192.168.50.100 "cd /tmp && go run setup-nfs-cache-proxmox.go"

# Step 3: Verify LXC mount
echo "[3/4] Verifying LXC mount..."
ssh root@192.168.50.100 "pct exec 101 -- df -h /srv/gitlab-runner/cache"

# Step 4: Setup GitLab Runner
echo "[4/4] Setting up GitLab Runner with cache..."
echo "  Run inside LXC 101:"
echo "    pct exec 101 -- bash"
echo "    go run /opt/runner/scripts/setup-gitlab-runner-with-cache.go"

echo ""
echo "=== Deployment Complete ==="
