# Alerting Reference

**Last Updated**: 2026-02-12

Complete reference for the homelab error handling and alerting pipeline.

## Architecture

```
Hosts (100, 101, 102, 104, 105, 106, 112)
  └─ Filebeat → Logstash:5044 (105)
       └─ 4-tier error classification (error_classification + error_severity)
            └─ Elasticsearch (105:9200, index: logs-YYYY.MM.dd)
                 ├─ ElastAlert2 (4 rules) → GlitchTip Sentry API (106:8000)
                 │    └─ GlitchTip webhook → n8n:5678 /webhook/glitchtip-error
                 │         └─ error-to-github-issue.json → GitHub Issues
                 └─ Grafana (104:3000, 12 rules) → n8n:5678 /webhook/grafana-alert
                      └─ alert-to-github-issue.json → GitHub Issues
```

## Data Flow

### 1. Collection (Filebeat)

Each host runs a static Filebeat config at `{host}/config/filebeat.yml`.

| Host      | VMID | Inputs                               | fields_under_root |
| --------- | ---- | ------------------------------------ | ----------------- |
| pve       | 100  | system, ceph, proxmox                | true              |
| runner    | 101  | system, github-runner                | true              |
| traefik   | 102  | system, traefik, traefik-access      | true              |
| grafana   | 104  | system, grafana                      | true              |
| elk       | 105  | system, elk-docker, mcp              | true              |
| glitchtip | 106  | system, glitchtip (Docker container) | true              |
| mcphub    | 112  | mcphub (Docker JSON), system         | true              |

> **Requirement**: All inputs **must** use `fields_under_root: true` — Logstash filters reference `[service]` at root level.

> **Note**: Filebeat configs are static files, NOT Terraform-managed.

### 2. Processing (Logstash)

Template: `105-elk/templates/logstash.conf.tftpl`

**Fields created by Logstash:**

| Field                  | Description            | Values                                                                                                                                        |
| ---------------------- | ---------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `error_classification` | Error category         | CRITICAL_FAILURE, RESOURCE_EXHAUSTION, CONNECTIVITY_FAILURE, GATEWAY_ERROR, AUTH_FAILURE, DATA_ERROR, APPLICATION_ERROR, DEPRECATION, WARNING |
| `error_severity`       | Severity level         | critical, high, medium, low                                                                                                                   |
| `service`              | Source service name    | mcphub, grafana, traefik, system, etc.                                                                                                        |
| `level`                | Log level (normalized) | error, warn, info                                                                                                                             |
| `log_message`          | Parsed log content     | "Connection refused"                                                                                                                          |
| `error_message`        | Error-specific message | "ECONNREFUSED"                                                                                                                                |
| `error_code`           | Error code if present  | -32601                                                                                                                                        |

**Tier Mapping:**

| Tier | Classifications                             | Severity | Triggers                              |
| ---- | ------------------------------------------- | -------- | ------------------------------------- |
| 1    | CRITICAL_FAILURE, RESOURCE_EXHAUSTION       | critical | fatal, panic, oom                     |
| 2    | CONNECTIVITY_FAILURE, GATEWAY_ERROR         | high     | connection refused, timeout, 502, 503 |
| 3    | AUTH_FAILURE, DATA_ERROR, APPLICATION_ERROR | medium   | unauthorized, 401, 403, parse error   |
| 4    | DEPRECATION, WARNING                        | low      | deprecated, warning                   |

**Query Examples:**

```
_exists_:error_classification                               # All classified errors
error_severity:critical                                      # Critical only
error_classification:GATEWAY_ERROR                           # Gateway errors
(service:mcp OR service:mcphub) AND _exists_:error_classification  # MCP errors
```

**Error handling:**

- Retry: initial=2s, max=64s, on_conflict=3
- DLQ: Failed events written to `/usr/share/logstash/dlq/failed-{date}.json`
- Native DLQ enabled in `logstash.yml`

### 3. Alerting — ElastAlert2

Rules directory: `105-elk/config/elastalert-rules/`

| Rule                   | Type      | Threshold         | Filter                                     | Destination            |
| ---------------------- | --------- | ----------------- | ------------------------------------------ | ---------------------- |
| `high-error-rate`      | frequency | 50 events / 5 min | `level:error`                              | GlitchTip (Sentry API) |
| `critical-error-spike` | frequency | 5 events / 1 min  | `level:critical OR level:fatal`            | GlitchTip (Sentry API) |
| `gateway-errors`       | frequency | 10 events / 5 min | `message:502 OR message:503`               | GlitchTip (Sentry API) |
| `mcp-errors`           | frequency | 20 events / 5 min | `service:["mcp","mcphub"] AND level:error` | GlitchTip (Sentry API) |

All rules post to GlitchTip via Sentry protocol at `http://192.168.50.106:8000`.

### 4. Alerting — Grafana

Config: `104-grafana/alerting.yaml`

**Contact point:** `n8n-webhook` → `http://192.168.50.112:5678/webhook/grafana-alert`

**Routing policies:**

| Severity | Group Wait | Repeat Interval |
| -------- | ---------- | --------------- |
| critical | 10s        | 1h              |
| warning  | 1m         | 4h              |
| info     | 2m         | 12h             |

**Alert rules (10 total, 3 groups):**

#### homelab-logs (folder: Alerting, eval: 1m)

| Rule                   | Severity | Source | Condition                           |
| ---------------------- | -------- | ------ | ----------------------------------- |
| `high-error-rate`      | warning  | ES     | >100 errors in 5 min                |
| `critical-error-spike` | critical | ES     | >5 fatal/panic/critical in 1 min    |
| `gateway-errors`       | warning  | ES     | >10 502/503 from traefik in 5 min   |
| `client-errors-spike`  | info     | ES     | >100 4xx from traefik in 5 min      |
| `host-silent`          | warning  | ES     | <5 unique hosts reporting in 10 min |

#### mcp-alerts (folder: MCP Alerts, eval: 1m)

| Rule             | Severity | Source | Condition               |
| ---------------- | -------- | ------ | ----------------------- |
| `mcp_error_logs` | warning  | ES     | >5 MCP errors in 10 min |

#### infrastructure-health (folder: Alerting, eval: 1m)

| Rule                  | Severity | Source     | Condition                    |
| --------------------- | -------- | ---------- | ---------------------------- |
| `service-down`        | critical | Prometheus | probe_success == 0 for 2 min |
| `disk-usage-high`     | warning  | Prometheus | >80% disk usage for 5 min    |
| `disk-usage-critical` | critical | Prometheus | >90% disk usage for 2 min    |
| `ssl-cert-expiry`     | warning  | Prometheus | SSL cert expires in <7 days  |

**Query improvements** (2026-02-12): All ES-based rules now use structured Logstash fields (`error_classification`, `error_severity`) instead of raw text matching, eliminating false positives from noise exclusion patterns.

### 5. Incident Creation (n8n)

n8n workflows on VM 112 (port 5678) create GitHub Issues from alerts.

| Webhook Path               | Source    | Labels                             |
| -------------------------- | --------- | ---------------------------------- |
| `/webhook/grafana-alert`   | Grafana   | `automated, infrastructure, alert` |
| `/webhook/glitchtip-error` | GlitchTip | `bug, glitchtip, automated`        |

### 6. Error Tracking (GlitchTip)

- URL: `http://192.168.50.106:8000`
- Org: `jclee-homelab`, Project: `homelab`
- Receives from: ElastAlert2 (Sentry protocol)
- Alert rule `n8n-automation` forwards to n8n webhook

## Datasource UIDs (Grafana)

| Datasource    | UID                 |
| ------------- | ------------------- |
| Elasticsearch | `P31C819B24CF3C3C7` |
| Prometheus    | `PBFA97CFB590B2093` |

## File Locations

| Component         | Path                                    |
| ----------------- | --------------------------------------- |
| Filebeat configs  | `{host}/config/filebeat.yml`            |
| Logstash template | `105-elk/templates/logstash.conf.tftpl` |
| Logstash config   | `105-elk/config/logstash.yml`           |
| ElastAlert rules  | `105-elk/config/elastalert-rules/*.yml` |
| Grafana alerting  | `104-grafana/alerting.yaml`             |
| n8n workflows     | `scripts/n8n-workflows/`                |

## Known Issues

- **SPOF**: Grafana has single contact point (n8n-webhook). No fallback if n8n is down.

## Deprecated

- `112-mcphub/n8n-workflows/elk-error-pipeline.json` — superseded by `scripts/n8n-workflows/error-to-github-issue.json`
- `105-elk/config/elastalert-rules.yml` — orphaned file, not mounted by Docker. Rules live in `elastalert-rules/` directory.
