# Service Down: Container/VM Restart

## Symptoms

- Service unreachable (HTTP 502/503 from Traefik)
- Grafana alert: `ServiceDown` or `ContainerHighCPU`
- Health endpoint returns error or timeout

## Quick Reference

| VMID | Service   | Type | Health Check                                         |
| ---- | --------- | ---- | ---------------------------------------------------- |
| 102  | Traefik   | LXC  | `curl -s http://192.168.50.102:8080/ping`            |
| 104  | Grafana   | LXC  | `curl -s http://192.168.50.104:3000/api/health`      |
| 105  | ELK       | LXC  | `curl -s http://192.168.50.105:9200/_cluster/health` |
| 106  | GlitchTip | LXC  | `curl -s http://192.168.50.106:8000/healthz`         |
| 112  | MCPHub    | VM   | `curl -s http://192.168.50.112:3000/`                |

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

**Traefik (102)** — Reverse proxy for all services:

```bash
pct exec 102 -- systemctl restart docker
pct exec 102 -- docker logs traefik --tail 20
```

**Grafana (104)** — Prometheus + Grafana:

```bash
pct exec 104 -- docker compose -f /opt/grafana/docker-compose.yml restart
pct exec 104 -- docker compose -f /opt/grafana/docker-compose.yml ps
```

**ELK (105)** — Elasticsearch + Logstash + Kibana:

```bash
pct exec 105 -- docker compose -f /opt/elk/docker-compose.yml restart
# Verify Elasticsearch cluster health
pct exec 105 -- curl -s localhost:9200/_cluster/health | jq .status
```

**GlitchTip (106)** — Error tracking:

```bash
pct exec 106 -- docker compose -f /opt/glitchtip/docker-compose.yml restart
pct exec 106 -- docker compose -f /opt/glitchtip/docker-compose.yml ps
```

**MCPHub (112)** — MCP Hub + n8n:

```bash
ssh root@192.168.50.112
docker compose -f /opt/mcphub/docker-compose.yml restart
docker compose -f /opt/n8n/docker-compose.yml restart
```

## Prevention

- Grafana alerts monitor all services via blackbox exporter
- Check `104-grafana/terraform/alerting_rules.tf` for alert configuration
- Alerts route to Slack (critical/warning) and alert-log-fallback (info)
