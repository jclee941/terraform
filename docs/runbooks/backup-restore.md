# Backup Restore from vzdump

## Symptoms
- Data loss after accidental deletion or corruption
- Container/VM not booting after failed update
- Need to roll back to known good state

## Critical Backup Targets

| VMID | Service | Type | Priority |
|------|---------|------|----------|
| 102 | Traefik | LXC | High — routing configs |
| 104 | Grafana | LXC | High — dashboards + Prometheus data |
| 105 | ELK | LXC | High — log pipeline configs |
| 112 | MCPHub | VM | High — MCP configs + n8n workflows |

## Diagnosis

```bash
ssh pve

# List available backups
vzdump --list

# Check backup storage
ls -lh /var/lib/vz/dump/

# Find backups for specific VMID
ls /var/lib/vz/dump/ | grep "vzdump-.*-{VMID}-"
```

## Resolution

### Restore LXC Container
```bash
ssh pve

# Stop the container first
pct stop {VMID}

# Restore from backup (overwrites existing)
pct restore {VMID} /var/lib/vz/dump/vzdump-lxc-{VMID}-{DATE}.tar.zst \
  --force --storage local-lvm

# Start restored container
pct start {VMID}
```

### Restore QEMU VM
```bash
ssh pve

# Stop the VM first
qm stop {VMID}

# Restore from backup
qm restore {VMID} /var/lib/vz/dump/vzdump-qemu-{VMID}-{DATE}.vma.zst \
  --force --storage local-lvm

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
- Grafana alert rules managed in `104-grafana/terraform/alerting_rules.tf`
- Retention policy: keep-daily=7, keep-weekly=4, keep-monthly=3
- Grafana alert for backup failures
- Test restores quarterly to verify backup integrity
