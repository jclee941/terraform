# Backup Strategy for jclee.me homelab

**Document Version:** 1.0
**Last Updated:** 2026-02-11
**Status:** Active
**Issue Reference:** #34

## Overview

This document defines the comprehensive backup strategy for the jclee.me homelab infrastructure. All critical LXC containers and VMs are automatically backed up using Proxmox's native **vzdump** utility with zstd compression and automated retention policies.

### What Gets Backed Up

| VMID | Name    | Type | Backup Schedule | Purpose                          |
| ---- | ------- | ---- | --------------- | -------------------------------- |
| 105  | elk     | LXC  | 02:00 UTC daily | ELK logging / Elasticsearch       |
| 200  | oc      | VM   | 03:00 UTC daily | OpenCode development environment |
| 220  | youtube | VM   | 03:00 UTC daily | Media worker                      |

### What's NOT Backed Up (Non-Critical)

- **100-pve**: Proxmox host itself (system-level config)
- **114 cliproxy**: Cloudflare connector and CI/CD host; rebuild from Terraform and service configuration
- **215 synology**: Physical NAS data is outside this Proxmox guest backup job

## Backup Storage & Infrastructure

| Setting                 | Value              | Notes                                           |
| ----------------------- | ------------------ | ----------------------------------------------- |
| **Storage Location**    | `pbs-backup` (PBS storage) | Proxmox Backup Server datastore                    |
| **Compression**         | zstd               | Modern, space-efficient                         |
| **Mode**                | snapshot           | Consistent point-in-time backups, zero downtime |
| **Frequency**           | Daily              | Automated via Proxmox scheduler                 |
| **Full vs Incremental** | Full               | Simplifies restore workflow                     |

## Retention Policy

Backups are automatically pruned based on age and frequency to balance storage and recovery window:

| Policy              | Value    | Rationale                                      |
| ------------------- | -------- | ---------------------------------------------- |
| **Keep Last**       | 7 daily  | 1 week of daily backups for immediate restore  |
| **Keep Weekly**     | 4 weeks  | 1 month rolling window via weekly snapshots    |
| **Keep Monthly**    | 3 months | Quarterly recovery option for audit/compliance |
| **Total Retention** | ~90 days | Balanced storage vs recovery window            |

### Retention Examples

Given today is 2026-02-11:

- **Daily backups kept**: 2026-02-11, 2026-02-10, ..., 2026-02-05 (7 days)
- **Weekly kept**: 2026-02-11, 2026-02-04, 2026-01-28, 2026-01-21
- **Monthly kept**: 2026-02-11, 2026-01-11, 2025-12-11

Oldest backup automatically deleted: ~2025-11-11 (90 days old)

## Backup Execution Details

### LXC Container (105)

**Schedule**: Daily at **02:00 UTC** (9:00 PM UTC-5)
**Command**:

```bash
pvesh create /cluster/backup \
  --vmid 105 \
  --schedule "0 2 * * *" \
  --storage pbs-backup \
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

### VMs (200-oc, 220-youtube)

**Schedule**: Daily at **03:00 UTC** (10:00 PM UTC-5)
**Command**:

```bash
pvesh create /cluster/backup \
  --vmid 200,220 \
  --schedule "0 3 * * *" \
  --storage pbs-backup \
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
   go run scripts/setup-backups.go
   ```

3. **Verify jobs created**:

   ```bash
   pvesh get /cluster/backup --output-format json-pretty
   ```

4. **Monitor first backup run**:
   - Visit Proxmox GUI → Datacenter → Backup
   - Or: `grep vzdump /var/log/syslog | tail -20`

## Restore Procedures

### LXC Container Restore (example: 105-elk)

**Prerequisites**:

- Backup snapshot available in `pbs-backup`
- Target VMID available or specify new VMID

**Procedure**:

1. **List available backups**:

   ```bash
   pvesh get /nodes/pve/storage/pbs-backup/content --content backup --output-format json-pretty
   ```

   Example output:

   ```
   -rw-r--r-- 1 root root 2.1G Feb 11 02:15 vzdump-lxc-105-2026_02_11-02_15_00.tar.zst
   ```

2. **Restore to new container (105-new)**:

   ```bash
   pvesh create /nodes/pve/lxc \
      --vmid 150 \
      --hostname elk-restored \
     --archive pbs-backup:backup/vzdump-lxc-105-2026_02_11-02_15_00.tar.zst \
     --storage hdd-local
   ```

   Or via GUI: Datacenter → Backup → select backup → Restore

3. **Start restored container**:

   ```bash
    pct start 150
   ```

4. **Verify network & services**:

   ```bash
   pct exec 150 -- ip a
   pct exec 150 -- systemctl status docker
   ```

5. **(Optional) Swap old for restored**:
   ```bash
   pct stop 105 && pct destroy 105
   pct move-storage 150 --storage local
   sed -i 's/150/105/' /etc/pve/nodes/pve/lxc/150.conf
   ```

### VM Restore (e.g., 220-youtube)

**Prerequisite**: Target VMID must be free (or destroyed first).

**Procedure**:

1. **List available backups**:

   ```bash
   pvesh get /nodes/pve/storage/pbs-backup/content --content backup --output-format json-pretty
   ```

2. **Restore to new VM**:

   ```bash
   qmrestore pbs-backup:backup/vzdump-qemu-220-2026_02_11-03_15_00.vma.zst 150 \
     --storage hdd-local
   ```

   Or via GUI: Datacenter → Backup → select backup → Restore

3. **Start restored VM**:

   ```bash
   qm start 150
   ```

4. **Verify QEMU guest agent**:

   ```bash
   qm agent 150 ping
   ```

5. **(Optional) Swap old for restored**:
   ```bash
   qm stop 220 && qm destroy 220
   qm set 150 --name youtube
   ```

### Partial Restore (Single Files from LXC)

If you only need to restore a subset of files:

1. **Download the backup archive from `pbs-backup`**:

   ```bash
   mkdir /tmp/restore
   tar -xf /path/to/downloaded/vzdump-lxc-105-2026_02_11-02_15_00.tar.zst \
     -C /tmp/restore --strip-components=1
   ```

2. **Extract specific files**:

   ```bash
   cp /tmp/restore/opt/elk/docker-compose.yml /tmp/docker-compose.yml.bak
   ```

3. **Restore to running container**:
   ```bash
   pct push 105 /tmp/docker-compose.yml.bak /opt/elk/docker-compose.yml.restored
   ```

## Verification & Testing

### Automated Verification

Backups are verified post-creation by Proxmox:

- `--mode snapshot` includes implicit verification
- Failed backups trigger email to `root@pve`

### Manual Verification

**Check backup file integrity**:

```bash
cd /path/to/downloaded/backups/
tar -tzf vzdump-lxc-105-2026_02_11-02_15_00.tar.zst | head -20
```

**Estimate restore time** (dry-run):

```bash
tar -tzf vzdump-lxc-105-2026_02_11-02_15_00.tar.zst | wc -l
```

**Monthly restore test** (recommended):

- On the 1st of each month, restore latest backup to test VMID
- Verify service startup and network connectivity
- Destroy test VMID after verification

## Disaster Recovery Scenarios

### Scenario 1: Single Service Failure

1. **Restore to temporary VMID** (e.g., 150)
2. **Start and verify services**
3. **Copy data/config back to original** if partial restore needed
4. **Destroy temporary VMID**

**RTO**: ~15 minutes | **RPO**: 24 hours

### Scenario 2: Full Host Failure (PVE Host)

Backups are stored in `pbs-backup`, so restoration requires the Proxmox host and PBS storage to be reachable:

1. **If PVE is recoverable**:
   - Boot PVE host from backup/snapshot
   - Restore containers/VMs from `pbs-backup`

2. **If PVE is destroyed**:
   - Backups are lost (single point of failure)
   - _Mitigation_: Implement offsite backup replication (future)

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

### Monitoring Alerts

Backup-related alert rules are managed through the monitoring template/config pipeline:

- **Host Silent**: Triggers if a host stops sending logs (possible backup failure)
- **Disk Usage High**: Alerts if `pbs-backup` exceeds 80% capacity

### Manual Check

```bash
# List recent backups in PBS storage
pvesh get /nodes/pve/storage/pbs-backup/content --content backup --output-format json-pretty

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

| VMID | Service | Backup storage | Sizing guidance |
| ---- | ------- | -------------- | --------------- |
| 105  | elk     | `pbs-backup`   | Measure actual archive size in PBS |
| 200  | oc      | `pbs-backup`   | Measure actual archive size in PBS |
| 220  | youtube | `pbs-backup`   | Measure actual archive size in PBS |

### Retention Storage

With 90-day retention (21 daily + 4 weekly + 3 monthly snapshots) in `pbs-backup`:

```
Query PBS storage usage and prune status rather than relying on a fixed size estimate.
```

**Current available**: `pbs-backup` storage (check with the Proxmox storage usage view)

### Future Scaling

When storage reaches 80%:

1. Reduce retention to `keep-last=3,keep-weekly=2,keep-monthly=2` (~40 GB)
2. Or: Implement offsite replication to object storage and delete local after 30 days

## Future Enhancements

- [ ] **Offsite replication**: Sync backups to offsite storage (e.g., S3-compatible) daily
- [ ] **Backup encryption**: Add `--encrypt key.pem` for sensitive containers
- [ ] **Selective backup**: Exclude large volumes (e.g., Elasticsearch indices) for faster backups
- [ ] **Backup testing**: Automated monthly restore-to-test VMID via CI workflow
- [ ] **Backup metrics**: Export backup duration/size to Prometheus for trending

## References

- [Proxmox Backup Documentation](https://pve.proxmox.com/wiki/Backup_and_Restore)
- [vzdump Manual](https://pve.proxmox.com/wiki/Backup_and_Restore#Using_vzdump)
- [Restore Guide](https://pve.proxmox.com/wiki/Backup_and_Restore#Restoring_Backups)
- Project: [AGENTS.md](./AGENTS.md)
- Infrastructure Status: [`100-pve/envs/prod/hosts.tf`](../100-pve/envs/prod/hosts.tf)
