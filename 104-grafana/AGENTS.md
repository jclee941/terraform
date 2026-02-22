# AGENTS.md - 104-Grafana

**Reason:** Observability Stack

## OVERVIEW

Centralized metrics stack and visualization engine (Prometheus/Grafana). Orchestrates **Prometheus** for time-series infrastructure metrics and **Grafana** for unified dashboarding. Consumes log data from **ELK Stack (105)** via Elasticsearch datasource for error tracking and automated issue classification. Includes **log-collection-health** dashboard and alert for monitoring Filebeat coverage.

## STRUCTURE

- `dashboards/`: Static JSON definitions for all 16 dashboards (Source of Truth).
- `provisioning/`: Standard Grafana configuration for datasources (ES/Prometheus) and dashboard providers.
- `tf-configs/`: Terraform-rendered outputs (Prometheus scrape targets, interpolated dashboard JSON).
- `templates/`: `.tftpl` sources for dynamic configuration rendering.
- `terraform/`: Standalone Grafana provider workspace. Alert rules (14 rules, 4 groups), dashboard folders, notification policies.
- `alerting.yaml`: Deprecated. Alert rules now managed in `terraform/main.tf`.

## WHERE TO LOOK

| Task                      | Location                                   | Notes                                           |
| ------------------------- | ------------------------------------------ | ----------------------------------------------- |
| **Datasource Config**     | `provisioning/datasources/datasources.yml` | Connection strings for Prometheus + ES          |
| **Dashboard Layouts**     | `dashboards/*.json`                        | Base JSON for visual design (16 dashboards)     |
| **Metric Scrapes**        | `tf-configs/prometheus.yml`                | Node-exporter targets & intervals               |
| **Alert Rules**           | `terraform/main.tf`                        | 14 rules in 4 groups (Terraform SSoT)           |
| **Interpolated JSON**     | `tf-configs/*.json`                        | Rendered dashboards with injected host IPs      |
| **Log Collection Health** | `dashboards/log-collection-health.json`    | Filebeat coverage and ingestion rate monitoring |
| **Logstash Metrics**      | `dashboards/logstash-metrics.json`         | Pipeline throughput, DLQ, exporter metrics      |

## CONVENTIONS

- **Code-Only Dashboards**: All visual modifications must occur in repo JSON files. Manual UI changes are ephemeral and will be overwritten.
- **Provider Mapping**: Uses Grafana's filesystem provider to sync `dashboards/` to the web interface.
- **Static UIDs**: Every dashboard JSON must include a persistent `uid` to prevent ID collisions.
- **Secrets**: `grafana_admin_password`, `grafana_service_account_token` from 1Password (`homelab/grafana`) via `onepassword-secrets` module.
- **Alert Routing**: All alerts trigger POST requests to the `n8n-webhook` on `112-mcphub` for automated GitHub Issue creation.
- **Prometheus Scrape Dedup**: Each target must appear in exactly one scrape config to avoid duplicate metrics.

## ANTI-PATTERNS

- **NO Manual UI Edits**: Do not save changes directly in the Grafana UI; they will be overwritten by Terraform/Provisioning.
- **NO Hardcoded Node IPs**: Use Terraform template variables (`${host_ip}`) for all cross-host references.
- **NO Loki/Promtail**: Deprecated. Use the Elasticsearch datasource for all log-based panels.
- **NO Local Alert Files**: Alert rules are Terraform-managed (`terraform/main.tf`). Do not create standalone alert YAML files.
