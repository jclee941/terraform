# Disk Full: Cleanup and Expansion

## Symptoms
- Services failing with "No space left on device"
- Grafana alert: `DiskSpaceWarning` or `DiskSpaceCritical`
- Container/VM unresponsive or read-only filesystem

## Diagnosis

```bash
ssh pve

# Check host disk usage
df -h

# Check specific container disk usage
pct exec {VMID} -- df -h

# Check Docker disk usage inside container
pct exec {VMID} -- docker system df
```

## Resolution

### 1. Docker Cleanup (inside container)
```bash
pct exec {VMID} -- bash -c '
  docker system prune -af --volumes
  docker builder prune -af
'
```

### 2. Log Cleanup

**Logstash/Elasticsearch (105):**
```bash
pct exec 105 -- bash -c '
  # Remove old indices (older than 30 days)
  curl -s -X DELETE "localhost:9200/filebeat-*-$(date -d "-30 days" +%Y.%m)*"

  # Check index sizes
  curl -s "localhost:9200/_cat/indices?v&s=store.size:desc" | head -20

  # Truncate logstash logs
  truncate -s 0 /var/log/logstash/*.log
'
```

**General log cleanup:**
```bash
pct exec {VMID} -- bash -c '
  # Truncate large log files
  find /var/log -name "*.log" -size +100M -exec truncate -s 0 {} \;

  # Remove old journal entries
  journalctl --vacuum-time=7d
'
```

### 3. Disk Expansion

**LXC Container:**
```bash
ssh pve

# Resize rootfs (add 5GB)
pct resize {VMID} rootfs +5G

# Verify inside container
pct exec {VMID} -- df -h /
```

**VM Disk:**
```bash
ssh pve

# Resize disk
qm resize {VMID} scsi0 +10G

# Inside VM, extend filesystem
ssh root@192.168.50.{IP} -- bash -c '
  growpart /dev/sda 1
  resize2fs /dev/sda1
'
```

## Prevention
- Elasticsearch ILM policy should auto-delete indices >30 days
- Docker log rotation: configure `max-size: 10m` and `max-file: 3` in daemon.json
- Grafana alert at 80% disk usage threshold
- Review `105-elk/config/` for index lifecycle settings
