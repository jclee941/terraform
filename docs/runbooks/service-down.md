# Service Down: Container/VM and Tunnel Recovery

## Symptoms

- Public hostname unreachable or Cloudflare edge error
- Alert or health-check failure for an active service
- Health endpoint returns error or timeout

## Quick Reference

| VMID | Service   | Type | Health Check                                         |
| ---- | --------- | ---- | ---------------------------------------------------- |
| 114  | cliproxy | LXC  | `systemctl is-active cloudflared-homelab`            |
| 105  | ELK       | LXC  | `curl -s http://192.168.50.105:9200/_cluster/health` |

## Diagnosis

```bash
# 1. Connect to Proxmox host
ssh pve

# 2. Check container/VM status
pct list          # LXC containers
qm list           # QEMU VMs

# 3. Check specific container
pct status {VMID}
pct exec {VMID} -- systemctl status docker  # Docker services
```

## Resolution

### LXC Container Restart

```bash
ssh pve

# Restart the container
pct restart {VMID}

# If restart fails, stop then start
pct stop {VMID}
pct start {VMID}

# Restart Docker services inside container
pct exec {VMID} -- systemctl restart docker
```

### VM Restart

```bash
ssh pve

# Graceful shutdown + start
qm shutdown {VMID}
qm start {VMID}

# Force stop if unresponsive
qm stop {VMID}
qm start {VMID}
```

### Service-Specific Recovery

**Cloudflare Tunnel (114)** — Native public ingress connector:

```bash
pct exec 114 -- systemctl restart cloudflared-homelab
pct exec 114 -- journalctl -u cloudflared-homelab -n 20 --no-pager
# Verify the affected direct origin separately, for example:
curl -s http://192.168.50.105:9200/_cluster/health
```

**ELK (105)** — Elasticsearch + Logstash + Kibana:

```bash
pct exec 105 -- docker compose -f /opt/elk/docker-compose.yml restart
# Verify Elasticsearch cluster health
pct exec 105 -- curl -s localhost:9200/_cluster/health | jq .status
```

## Prevention

- Active service alerts and health checks should route through the current monitoring pipeline.
- Check the alerting template/config source for alert configuration.
