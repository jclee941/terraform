# Backup Strategy for jclee.me Homelab

**Document Version:** 1.0  
**Last Updated:** 2026-02-11  
**Status:** Active  
**Issue Reference:** #34

## Overview

This document defines the comprehensive backup strategy for the jclee.me homelab infrastructure. All critical LXC containers and VMs are automatically backed up using Proxmox's native **vzdump** utility with zstd compression and automated retention policies.

### What Gets Backed Up

| VMID | Name | Type | Backup Schedule | Purpose |
|------|------|------|-----------------|---------|
| 102 | traefik | LXC | 02:00 UTC daily | Reverse proxy / edge router |
| 104 | grafana | LXC | 02:00 UTC daily | Observability stack |
| 105 | elk | LXC | 02:00 UTC daily | ELK logging / Elasticsearch |
| 106 | glitchtip | LXC | 02:00 UTC daily | Error tracking |
| 112 | mcphub | VM | 03:00 UTC daily | MCP Hub + n8n automation |

### What's NOT Backed Up (Non-Critical)

- **100-pve**: Proxmox host itself (system-level config)
- **101-runner**: GitHub Actions runner (ephemeral, re-deployable via Terraform)
- **200-oc**: Dev environment (rebuild from cloud-init)
- **220-sandbox**: Sandbox (ephemeral)

## Backup Storage & Infrastructure

| Setting | Value | Notes |
|---------|-------|-------|
| **Storage Location** | `local` (PVE host) | `/var/lib/vz/dump/` |
| **Compression** | zstd | Modern, space-efficient |
| **Mode** | snapshot | Consistent point-in-time backups, zero downtime |
| **Frequency** | Daily | Automated via Proxmox scheduler |
| **Full vs Incremental** | Full | Simplifies restore workflow |

## Retention Policy

Backups are automatically pruned based on age and frequency to balance storage and recovery window:

| Policy | Value | Rationale |
|--------|-------|-----------|
| **Keep Last** | 7 daily | 1 week of daily backups for immediate restore |
| **Keep Weekly** | 4 weeks | 1 month rolling window via weekly snapshots |
| **Keep Monthly** | 3 months | Quarterly recovery option for audit/compliance |
| **Total Retention** | ~90 days | Balanced storage vs recovery window |

### Retention Examples

Given today is 2026-02-11:
- **Daily backups kept**: 2026-02-11, 2026-02-10, ..., 2026-02-05 (7 days)
- **Weekly kept**: 2026-02-11, 2026-02-04, 2026-01-28, 2026-01-21
- **Monthly kept**: 2026-02-11, 2026-01-11, 2025-12-11

Oldest backup automatically deleted: ~2025-11-11 (90 days old)

## Backup Execution Details

### LXC Containers (102, 104, 105, 106)

**Schedule**: Daily at **02:00 UTC** (9:00 PM UTC-5)
**Command**:
```bash
pvesh create /cluster/backup \
  --vmid 102,104,105,106 \
  --schedule "0 2 * * *" \
  --storage local \
  --mode snapshot \
  --compress zstd \
  --prune-backups keep-last=7,keep-weekly=4,keep-monthly=3 \
  --enabled 1 \
  --notes-template "{{guestname}}-daily" \
  --mailto root
```

**Benefits**:
- `--mode snapshot`: Quiescent snapshots, zero downtime during backup
- `--compress zstd`: Modern compression (better than gzip/lzo)
- Notification to root upon completion/failure

### VM (112-mcphub)

**Schedule**: Daily at **03:00 UTC** (10:00 PM UTC-5)  
**Command**:
```bash
pvesh create /cluster/backup \
  --vmid 112 \
  --schedule "0 3 * * *" \
  --storage local \
  --mode snapshot \
  --compress zstd \
  --prune-backups keep-last=7,keep-weekly=4,keep-monthly=3 \
  --enabled 1 \
  --notes-template "{{guestname}}-daily" \
  --mailto root
```

**Rationale**: Staggered from LXCs to avoid backup storms on the host.

## Setup Instructions

### On PVE Host (192.168.50.100)

1. **SSH to PVE**:
   ```bash
   ssh root@192.168.50.100
   ```

2. **Run backup setup script**:
   ```bash
   bash scripts/setup-backups.sh
   ```

3. **Verify jobs created**:
   ```bash
   pvesh get /cluster/backup --output-format json-pretty
   ```

4. **Monitor first backup run**:
   - Visit Proxmox GUI → Datacenter → Backup
   - Or: `grep vzdump /var/log/syslog | tail -20`

## Restore Procedures

### LXC Container Restore (e.g., 104-grafana)

**Prerequisites**:
- Backup file located at `/var/lib/vz/dump/`
- Target VMID available or specify new VMID

**Procedure**:

1. **List available backups**:
   ```bash
   ls -lah /var/lib/vz/dump/ | grep 104
   ```
   Example output:
   ```
   -rw-r--r-- 1 root root 2.1G Feb 11 02:15 vzdump-lxc-104-2026_02_11-02_15_00.tar.zst
   ```

2. **Restore to new container (105-new)**:
   ```bash
   pvesh create /nodes/pve/lxc \
     --vmid 109 \
     --hostname grafana-restored \
     --archive /var/lib/vz/dump/vzdump-lxc-104-2026_02_11-02_15_00.tar.zst
   ```
   Or via GUI: Datacenter → Backup → select backup → Restore

3. **Start restored container**:
   ```bash
   pct start 109
   ```

4. **Verify network & services**:
   ```bash
   pct exec 109 -- ip a
   pct exec 109 -- systemctl status grafana-server
   ```

5. **(Optional) Swap old for restored**:
   ```bash
   pct stop 104 && pct destroy 104
   pct move-storage 109 --storage local
   sed -i 's/109/104/' /etc/pve/nodes/pve/lxc/109.conf
   ```

### VM Restore (e.g., 112-mcphub)

**Prerequisite**: Target VMID must be free (or destroyed first).

**Procedure**:

1. **List available backups**:
   ```bash
   ls -lah /var/lib/vz/dump/ | grep 112
   ```

2. **Restore to new VM**:
   ```bash
   qmrestore /var/lib/vz/dump/vzdump-qemu-112-2026_02_11-03_15_00.vma.zst 113 \
     --storage local-lvm
   ```
   Or via GUI: Datacenter → Backup → select backup → Restore

3. **Start restored VM**:
   ```bash
   qm start 113
   ```

4. **Verify QEMU guest agent**:
   ```bash
   qm agent 113 ping
   ```

5. **(Optional) Swap old for restored**:
   ```bash
   qm stop 112 && qm destroy 112
   qm set 113 --name mcphub
   ```

### Partial Restore (Single Files from LXC)

If you only need to restore a subset of files:

1. **Mount backup archive**:
   ```bash
   mkdir /tmp/restore
   tar -xf /var/lib/vz/dump/vzdump-lxc-104-2026_02_11-02_15_00.tar.zst \
     -C /tmp/restore --strip-components=1
   ```

2. **Extract specific files**:
   ```bash
   cp /tmp/restore/etc/grafana/grafana.ini /tmp/grafana.ini.bak
   ```

3. **Restore to running container**:
   ```bash
   pct push 104 /tmp/grafana.ini.bak /etc/grafana/grafana.ini.restored
   ```

## Verification & Testing

### Automated Verification

Backups are verified post-creation by Proxmox:
- `--mode snapshot` includes implicit verification
- Failed backups trigger email to `root@pve`

### Manual Verification

**Check backup file integrity**:
```bash
cd /var/lib/vz/dump/
tar -tzf vzdump-lxc-104-2026_02_11-02_15_00.tar.zst | head -20
```

**Estimate restore time** (dry-run):
```bash
tar -tzf vzdump-lxc-104-2026_02_11-02_15_00.tar.zst | wc -l
```

**Monthly restore test** (recommended):
- On the 1st of each month, restore latest backup to test VMID
- Verify service startup and network connectivity
- Destroy test VMID after verification

## Disaster Recovery Scenarios

### Scenario 1: Single Service Failure (e.g., Grafana)

1. **Restore to temporary VMID** (e.g., 109)
2. **Start and verify services**
3. **Copy data/config back to original** if partial restore needed
4. **Destroy temporary VMID**

**RTO**: ~15 minutes | **RPO**: 24 hours

### Scenario 2: Full Host Failure (PVE Host)

Backups are stored locally on PVE, so restoration depends on PVE availability:

1. **If PVE is recoverable**:
   - Boot PVE host from backup/snapshot
   - Restore containers/VMs from `/var/lib/vz/dump/`

2. **If PVE is destroyed**:
   - Backups are lost (single point of failure)
   - *Mitigation*: Implement offsite backup replication (future)

**RTO**: Depends on PVE recovery | **RPO**: 24 hours

### Scenario 3: Data Corruption (e.g., Database)

1. **Identify backup date** before corruption occurred
2. **Restore container/VM to temporary VMID**
3. **Extract specific database** from restored state
4. **Merge restored data** into running system

**RTO**: ~30 minutes | **RPO**: 24 hours

## Backup Monitoring & Alerts

### Email Notifications

Backups send completion/failure emails to `root@pve`. Check:
```bash
tail -50 /var/mail/root
# or
journalctl -u postfix -f
```

### Grafana Alerts

Two backup-related alert rules (in 104-grafana/alerting.yaml):
- **Host Silent**: Triggers if a host stops sending logs (possible backup failure)
- **Disk Usage High**: Alerts if `/var/lib/vz/dump/` exceeds 80% capacity

### Manual Check

```bash
# List recent backups
ls -lht /var/lib/vz/dump/ | head -10

# Check backup schedule
pvesh get /cluster/backup

# Monitor ongoing backup
journalctl -u pvebackup -f
# or
tail -f /var/log/syslog | grep vzdump
```

## Capacity Planning

### Storage Consumption

Estimated daily backup sizes (with zstd compression):

| VMID | Service | Uncompressed | Compressed (zstd) | Daily Growth |
|------|---------|--------------|-------------------|--------------|
| 102 | traefik | ~500 MB | ~150 MB | 150 MB |
| 104 | grafana | ~1.5 GB | ~400 MB | 400 MB |
| 105 | elk | ~4.0 GB | ~1.2 GB | 1.2 GB |
| 106 | glitchtip | ~800 MB | ~250 MB | 250 MB |
| 112 | mcphub | ~2.0 GB | ~600 MB | 600 MB |
| **Total** | | **8.8 GB** | **~2.6 GB** | **~2.6 GB** |

### Retention Storage

With 90-day retention (21 daily + 4 weekly + 3 monthly snapshots):

```
~2.6 GB/day × ~28 backups (average) = ~73 GB total retention
```

**Current available**: `/var/lib/vz/dump/` on PVE (check with `df -h`)

### Future Scaling

When storage reaches 80%:
1. Reduce retention to `keep-last=3,keep-weekly=2,keep-monthly=2` (~40 GB)
2. Or: Implement offsite replication (S3/MinIO) and delete local after 30 days

## Future Enhancements

- [ ] **Offsite replication**: Sync backups to offsite storage (e.g., S3-compatible) daily
- [ ] **Backup encryption**: Add `--encrypt key.pem` for sensitive containers
- [ ] **Selective backup**: Exclude large volumes (e.g., Elasticsearch indices) for faster backups
- [ ] **Backup testing**: Automated monthly restore-to-test VMID via n8n workflow
- [ ] **Backup metrics**: Export backup duration/size to Prometheus for trending

## References

- [Proxmox Backup Documentation](https://pve.proxmox.com/wiki/Backup_and_Restore)
- [vzdump Manual](https://pve.proxmox.com/wiki/Backup_and_Restore#Using_vzdump)
- [Restore Guide](https://pve.proxmox.com/wiki/Backup_and_Restore#Restoring_Backups)
- Project: [AGENTS.md](./AGENTS.md)
- Infrastructure Status: [terraform/envs/prod/hosts.tf](./terraform/envs/prod/hosts.tf)
