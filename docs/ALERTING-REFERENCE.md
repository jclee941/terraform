# Alerting Reference

**Last Updated**: 2026-02-24

Complete reference for the homelab error handling and alerting pipeline.

## Architecture

```
Hosts (100, 101, 102, 103, 104, 105, 112)
  └─ Filebeat → Logstash:5044 (105)
       └─ 4-tier error classification (error_classification + error_severity)
            └─ Elasticsearch (105:9200, index: logs-YYYY.MM.dd)
                       ├─ slack-alerts → Slack (critical + warning)
                       └─ alert-log-fallback (info + default)
```

## Data Flow

### 1. Collection (Filebeat)

Each host runs a Filebeat config deployed via Terraform (`lxc-config`/`vm-config` modules).

| Host      | VMID | Inputs                               | fields_under_root |
| --------- | ---- | ------------------------------------ | ----------------- |
| pve       | 100  | system, ceph, proxmox                | true              |
| runner    | 101  | system, github-runner                | true              |
| traefik   | 102  | system, traefik, traefik-access      | true              |
| coredns   | 103  | Docker autodiscover, system          | true              |
| grafana   | 104  | system, grafana                      | true              |
| elk       | 105  | system, elk-docker, mcp              | true              |
| mcphub    | 112  | mcphub (Docker JSON), system         | true              |

> **Requirement**: All inputs **must** use `fields_under_root: true` — Logstash filters reference `[service]` at root level.

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

### 3. Alerting — Grafana

Config: `104-grafana/terraform/main.tf` (Terraform-managed alert rules)

**Contact points:**

| Contact Point            | Target                                                          |
| ------------------------ | --------------------------------------------------------------- |
| `alert-log-fallback`     | Grafana log (default fallback)                                  |
| `slack-alerts`           | Slack incoming webhook (conditional on webhook URL)              |

**Routing policies:**

| Severity | Contact Point           | Group Wait | Repeat Interval |
| -------- | ----------------------- | ---------- | --------------- |
| critical | slack-alerts            | 10s        | 1h              |
| warning  | slack-alerts            | 1m         | 4h              |
| info     | alert-log-fallback      | 2m         | 12h             |

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

## Datasource UIDs (Grafana)

| Datasource    | UID                 |
| ------------- | ------------------- |
| Elasticsearch | `P31C819B24CF3C3C7` |
| Prometheus    | `PBFA97CFB590B2093` |

## File Locations

| Component         | Path                                                |
| ----------------- | --------------------------------------------------- |
| Filebeat configs  | Terraform-deployed via lxc-config/vm-config modules |
| Logstash template | `105-elk/templates/logstash.conf.tftpl`             |
| Logstash config   | `105-elk/config/logstash.yml`                       |
| Grafana alerts    | `104-grafana/terraform/alerting_rules.tf`           |
| n8n workflows     | `scripts/n8n-workflows/`                            |

## Known Issues


## Deprecated

- `112-mcphub/n8n-workflows/elk-error-pipeline.json` — superseded by `scripts/n8n-workflows/error-to-github-issue.json`
- ElastAlert2 — removed. All threshold alerting migrated to Grafana alert rules (10 rules, 3 groups).
