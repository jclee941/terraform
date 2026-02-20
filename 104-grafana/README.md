# 104-grafana: Centralized Observability Stack

## 1. Service Overview
- **Service Name**: Observability Suite (Grafana, Prometheus)
- **Host IP**: `192.168.50.104` (LXC)
- **Purpose**: The "Single Pane of Glass" for the `jclee.me` homelab. It aggregates metrics, logs, and alerts from all active infrastructure nodes.
- **Current Status**: **Online**. Active dashboards include homelab overview, MCP Logs, and Infrastructure Metrics.
- **Components**:
  - **Grafana** (Port 3000): Visualization and alerting UI.
  - **Prometheus** (Port 9090): Time-series metrics database.

## 2. Configuration Files
Configurations follow a monorepo-provisioning model:
- **Grafana Provisioning**: `/opt/grafana/config/grafana/provisioning/` - Defines datasources and dashboard providers.
- **Dashboards (As Code)**: `/opt/grafana/config/grafana/dashboards/` - JSON definitions for all 7 active dashboards.
- **Prometheus Config**: `/etc/prometheus/prometheus.yml` - Defines scrape intervals and target lists (all nodes on port 9100).

## 3. Operations
### Lifecycle Commands
```bash
# SSH into the observability container
ssh grafana

# Check service status
systemctl status grafana-server
systemctl status prometheus

# Maintenance Scripts
scripts/status-check.sh   # Comprehensive health report
scripts/sync-dashboards.sh # Pushes local JSON files to the Grafana API
```

### Access
- **Web UI**: [https://grafana.jclee.me](https://grafana.jclee.me)
- **Internal API**: `http://192.168.50.104:3000`

## 4. Dependencies
- **Infrastructure Nodes**: Depends on `node_exporter` running on all active hosts (100, 102, 104, 105, 106, 107, 108, 112).
- **102-traefik**: Provides HTTPS ingress and certificate management.
- **112-mcphub (n8n)**: Receives alert webhooks for external notifications (GitHub Issues).

## 5. Troubleshooting
### Common Issues
- **Missing Logs**: Filebeat is unable to reach Logstash or has permission issues on `/var/log`.
  - *Fix*: Check `journalctl -u filebeat -f` on the source host and verify Logstash (105:5044) is reachable.
- **Elasticsearch Errors**: Often caused by index issues or disk space on ELK (105).
  - *Fix*: Check Elasticsearch health at `http://192.168.50.105:9200/_cluster/health`.
- **Stale Metrics**: Prometheus scrape job failing for a specific node.
  - *Fix*: Visit `http://192.168.50.104:9090/targets` to identify the failing node.
- **Dashboard "Read-Only"**: Provisioned dashboards cannot be edited in the UI.
  - *Fix*: Modify the JSON file in `config/grafana/dashboards/` and sync.

## 6. Dashboards
| Name | Purpose |
|------|---------|
| **Container Metrics** | Per-container resource monitoring. |
| **Infra Overview** | High-level status of all active hosts. |
| **Log Analytics** | Search logs across all hosts via Elasticsearch queries. |
| **Network Overview** | Network traffic and connectivity monitoring. |
| **Node Metrics** | Host-level CPU/MEM/Disk metrics. |
| **Service Health** | Service availability and uptime tracking. |
| **SLA Dashboard** | SLA compliance and availability targets. |

## 7. Governance
- **Style**: Google3 Monorepo
- **Provisioning**: UI changes are ephemeral; always update the JSON configs in the repo.
- **Retention**: Metrics are kept for 30 days. Log retention is managed by ELK ILM policy (105).
