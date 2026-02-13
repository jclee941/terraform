# Alerting System Reference

## A. Overview
The homelab alerting system follows a 6-layer pipeline designed for high-granularity log analysis and automated incident response.
Pipeline: Hosts -> Filebeat -> Logstash:5044 -> Elasticsearch -> ElastAlert2/Grafana -> GlitchTip/n8n -> GitHub Issues.

## B. Architecture Diagram
```
Hosts(100,102,104,105,106,112,200) -> Filebeat -> Logstash:5044 -> Elasticsearch
                                                                      |
                                                  ElastAlert2 -> GlitchTip(106)
                                                  Grafana(104) -> n8n(112) -> GitHub Issues
                                                  Grafana(104) -> Slack (critical only, backup)
```

## C. Layer 1: Log Collection (Filebeat)
Logs are shipped from all infrastructure nodes using Filebeat.

| Host | VMID | IP | Log Sources | Config Path |
|------|------|----|-------------|-------------|
| pve | 100 | 192.168.50.100 | system logs | 100-pve/config/filebeat.yml |
| traefik | 102 | 192.168.50.102 | system, traefik.log, traefik-access.log | 102-traefik/config/filebeat.yml |
| grafana | 104 | 192.168.50.104 | system logs | 104-grafana/config/filebeat.yml |
| elk | 105 | 192.168.50.105 | system, docker, MCP logs | 105-elk/config/filebeat.yml |
| glitchtip | 106 | 192.168.50.106 | system, glitchtip logs | 106-glitchtip/config/filebeat.yml |
| mcphub | 112 | 192.168.50.112 | docker containers, system | 112-mcphub/config/filebeat.yml |
| oc | 200 | 192.168.50.200 | system, auth, opencode logs | 200-oc/config/filebeat.yml |

All shippers use `fields_under_root: true` and output directly to the Logstash ingest point at `192.168.50.105:5044`.

## D. Layer 2: Log Processing (Logstash)
Logstash acts as the central normalization engine.
- Config: `105-elk/config/logstash.conf` (static) / `105-elk/templates/logstash.conf.tftpl` (Terraform template).
- Input: `beats:5044`, `syslog:5000`.
- Filter: service extraction, syslog grokking, JSON parsing, level normalization, and 4-tier error classification.
- Tier system: Tier1=fatal/panic, Tier2=connectivity/gateway, Tier3=auth/data/app, Tier4=deprecation/warning.
- Error codes: CRITICAL_FAILURE, RESOURCE_EXHAUSTION, CONNECTIVITY_FAILURE, GATEWAY_ERROR, AUTH_FAILURE, DATA_ERROR, APPLICATION_ERROR, DEPRECATION, WARNING.
- Output: Elasticsearch index `logs-YYYY.MM.dd`, Prometheus metrics available on `:9198`.
- Resilience: Dead Letter Queue (DLQ) enabled via `logstash.yml`, `retry_on_conflict=3`.

## E. Layer 3: Storage (Elasticsearch 8.12.0)
- Single-node deployment optimized for homelab usage.
- Security: xpack.security disabled, 2GB heap allocation.
- ILM Policy: `homelab-logs-30d` (Hot phase -> Delete after 30 days).
- Replicas: 0 (Single node cluster, replicas remain unassigned).
- Tiers: No warm phase or rollover implemented to simplify operations for low-volume logs.
- Index Templates: `logs-template` (patterns `logs-*`, priority 200), `elastalert-template` (patterns `elastalert_*`, priority 50).

## F. Layer 4a: ElastAlert2
ElastAlert2 runs on the ELK stack (105) and monitors Elasticsearch indices for specific patterns, posting alerts to GlitchTip via the Sentry protocol.
1. `critical-error-spike`: Fires on >=5 fatal/panic events in 1 minute.
2. `high-error-rate`: Fires on >=50 errors in 5 minutes (based on `tier` field).
3. `gateway-errors`: Fires on >=10 gateway errors in 5 minutes (based on `error_code:GATEWAY_ERROR`).
4. `mcp-errors`: Fires on >=5 MCP errors in 5 minutes (based on `service:mcp`).
Config rules are located in `105-elk/config/elastalert-rules/`.

## G. Layer 4b: Grafana Alerting
Grafana provides visual alerting and infrastructure health monitoring.
- Alert Groups:
    1. `homelab-logs`: high-error-rate, critical-error-spike, gateway-errors, client-errors-spike, host-silent.
    2. `opencode-alerts`: session-activity, errors.
    3. `mcp-alerts`: error-logs.
    4. `infrastructure-health`: service-down, disk-usage-high, disk-usage-critical, ssl-cert-expiry.
- Data Sources:
    - Elasticsearch UID: `P31C819B24CF3C3C7`
    - Prometheus UID: `PBFA97CFB590B2093`
- Config: `104-grafana/alerting.yaml`.

## H. Contact Points
| Name | Type | Target | Used For |
|------|------|--------|----------|
| n8n-webhook | Webhook | http://192.168.50.112:5678/webhook/grafana-alert | All alerts (primary) |
| slack-webhook | Slack | Slack incoming webhook | Critical alerts (backup) |

## I. Routing Policies
- Root Route: `n8n-webhook`, grouped by `[grafana_folder, alertname]`.
- Specific Routes:
    - `severity=critical`: Dispatches to `n8n-webhook` (continue: true) and `slack-webhook`. Evaluation: 10s, Grouping: 1m, Repeat: 1h.
    - `severity=warning`: Dispatches to `n8n-webhook`. Evaluation: 1m, Grouping: 5m, Repeat: 4h.
    - `severity=info`: Dispatches to `n8n-webhook`. Evaluation: 2m, Grouping: 10m, Repeat: 12h.

## J. Layer 5: GlitchTip (Error Tracking)
- Hosted on LXC 106 (`192.168.50.106:8000`).
- Receives aggregated alerts from ElastAlert2 via Sentry protocol.
- Web Interface: `glitchtip.jclee.me`, Organization: `jclee-homelab`.

## K. Layer 6: n8n (Automation)
- Hosted on VM 112, port 5678.
- Workflows:
    - Grafana Alert -> GitHub Issue.
    - GlitchTip Error -> GitHub Issue.
    - Daily Infrastructure Digest (scheduled via cron).

## L. Troubleshooting
```bash
# Check Filebeat status on a host
ssh root@192.168.50.100 'pct exec {VMID} -- systemctl status filebeat'

# Check Logstash pipeline stats
curl -s http://192.168.50.105:9600/_node/stats/pipelines | jq .

# Check Elasticsearch cluster health
curl -s http://192.168.50.105:9200/_cluster/health | jq .

# Search recent logs in Elasticsearch
curl -s http://192.168.50.105:9200/logs-*/_search?size=5 | jq .

# Check ElastAlert2 container logs
ssh root@192.168.50.100 'pct exec 105 -- docker logs elk-elastalert2-1 --tail 20'

# List active Grafana alerts via API
curl -s http://192.168.50.104:3000/api/alertmanager/grafana/api/v2/alerts | jq .
```

## M. Known Limitations
- Single Elasticsearch Node: Lack of replica redundancy is an intentional tradeoff for reduced complexity in the homelab environment.
- ILM Limitations: No warm phase or rollover is implemented, as log volume does not yet justify the additional overhead.
- Alert Protocol: ElastAlert2 to GlitchTip integration uses the Sentry protocol, which is one-way and lacks an acknowledgment mechanism.
