# Backup Restore from vzdump

## Symptoms
- Data loss after accidental deletion or corruption
- Container/VM not booting after failed update
- Need to roll back to known good state

## Critical Backup Targets

| VMID | Service | Type | Priority |
|------|---------|------|----------|
| 105 | ELK | LXC | High — log pipeline configs |

## Diagnosis

```bash
ssh pve

# List available backups
vzdump --list

# Check PBS backup storage
pvesh get /nodes/pve/storage/pbs-backup/content --content backup --output-format json-pretty

# Find backups for a specific VMID in PBS output
pvesh get /nodes/pve/storage/pbs-backup/content --content backup --output-format json-pretty
```

## Resolution

### Restore LXC Container
```bash
ssh pve

# Stop the container first
pct stop {VMID}

# Restore from backup (overwrites existing)
pct restore {VMID} pbs-backup:backup/vzdump-lxc-{VMID}-{DATE}.tar.zst \
  --force --storage hdd-local

# Start restored container
pct start {VMID}
```

### Restore QEMU VM
```bash
ssh pve

# Stop the VM first
qm stop {VMID}

# Restore from backup
qm restore {VMID} pbs-backup:backup/vzdump-qemu-{VMID}-{DATE}.vma.zst \
  --force --storage hdd-local

# Start restored VM
qm start {VMID}
```

### Post-Restore Checklist
```bash
# 1. Verify network
pct exec {VMID} -- ip addr show
pct exec {VMID} -- ping -c 3 192.168.50.1

# 2. Verify Docker services (if applicable)
pct exec {VMID} -- docker ps

# 3. Verify service health
curl -s http://192.168.50.{LAST_OCTET}:{PORT}/health

# 4. Check logs for errors
pct exec {VMID} -- journalctl -n 50 --no-pager
```

## Prevention
- Scheduled vzdump backups configured via Proxmox UI
- Alert rules managed through the template/config pipeline
- Retention policy: keep-daily=7, keep-weekly=4, keep-monthly=3
- Alert for backup failures
- Test restores quarterly to verify backup integrity
