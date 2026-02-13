#!/bin/bash
# Setup Proxmox vzdump backup jobs
# Run on PVE host (192.168.50.100) as root
# 
# This script creates automated backup jobs for critical LXC containers and VMs
# using Proxmox's native vzdump backup utility with zstd compression and
# retention policies.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
STORAGE="local"
COMPRESS="zstd"
LXC_VMIDS="102,104,105,106"
VM_VMIDS="112"
LXC_SCHEDULE="0 2 * * *"  # Daily 02:00 UTC
VM_SCHEDULE="0 3 * * *"   # Daily 03:00 UTC

echo -e "${YELLOW}=== Proxmox Backup Job Configuration ===${NC}"
echo "Storage: $STORAGE"
echo "Compression: $COMPRESS"
echo "LXC Containers (02:00 UTC): $LXC_VMIDS"
echo "VMs (03:00 UTC): $VM_VMIDS"
echo ""

# Verify running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[ERROR] This script must be run as root${NC}"
   exit 1
fi

# Verify Proxmox environment
if ! command -v pvesh &> /dev/null; then
   echo -e "${RED}[ERROR] pvesh command not found. Are you on the PVE host?${NC}"
   exit 1
fi

echo -e "${YELLOW}[INFO] Creating LXC container backup job...${NC}"
pvesh create /cluster/backup \
  --vmid "$LXC_VMIDS" \
  --schedule "$LXC_SCHEDULE" \
  --storage "$STORAGE" \
  --mode snapshot \
  --compress "$COMPRESS" \
  --prune-backups keep-last=7,keep-weekly=4,keep-monthly=3 \
  --enabled 1 \
  --notes-template "{{guestname}}-daily" \
  --mailto root

if [[ $? -eq 0 ]]; then
  echo -e "${GREEN}[OK] LXC backup job created${NC}"
else
  echo -e "${RED}[ERROR] Failed to create LXC backup job${NC}"
  exit 1
fi

echo ""
echo -e "${YELLOW}[INFO] Creating VM backup job...${NC}"
pvesh create /cluster/backup \
  --vmid "$VM_VMIDS" \
  --schedule "$VM_SCHEDULE" \
  --storage "$STORAGE" \
  --mode snapshot \
  --compress "$COMPRESS" \
  --prune-backups keep-last=7,keep-weekly=4,keep-monthly=3 \
  --enabled 1 \
  --notes-template "{{guestname}}-daily" \
  --mailto root

if [[ $? -eq 0 ]]; then
  echo -e "${GREEN}[OK] VM backup job created${NC}"
else
  echo -e "${RED}[ERROR] Failed to create VM backup job${NC}"
  exit 1
fi

echo ""
echo -e "${GREEN}[SUCCESS] Backup jobs configured successfully${NC}"
echo ""
echo -e "${YELLOW}=== Current Backup Jobs ===${NC}"
pvesh get /cluster/backup --output-format json-pretty | jq '.data' 2>/dev/null || \
  pvesh get /cluster/backup

echo ""
echo -e "${YELLOW}=== Next Steps ===${NC}"
echo "1. Monitor backup execution in Proxmox GUI > Datacenter > Backup"
echo "2. Check backup logs: grep vzdump /var/log/syslog"
echo "3. Verify restoration: docs/backup-strategy.md"
