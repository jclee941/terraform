# AGENTS: 104-grafana

## OVERVIEW

Centralized metrics stack and visualization engine (Prometheus/Grafana). Orchestrates **Prometheus** for time-series infrastructure metrics and **Grafana** for unified dashboarding. Consumes log data from **ELK Stack (105)** via Elasticsearch datasource for error tracking and automated issue classification. Includes **log-collection-health** dashboard and alert for monitoring Filebeat coverage.

## STRUCTURE

- `dashboards/`: Static JSON definitions for all 16 dashboards (Source of Truth).
- `provisioning/`: Standard Grafana configuration for datasources (ES/Prometheus) and dashboard providers.
- `tf-configs/`: Terraform-rendered outputs (Prometheus scrape targets, interpolated dashboard JSON).
- `templates/`: `.tftpl` sources for dynamic configuration rendering.
- `terraform/`: Standalone Grafana provider workspace. Split into: `main.tf` (folders, data sources, dashboards), `contact_points.tf` (4 contact points incl. GlitchTip bridge), `notification_policy.tf` (default policy with 7 sub-policies), `alerting_locals.tf` (ES + Prometheus alert rule definitions), `alerting_rules.tf` (3 rule groups: homelab_logs, infrastructure_health, mcp_alerts — 14 rules total), `service_accounts.tf` (2 service accounts + tokens).
- `alerting.yaml`: Deprecated. Alert rules now managed in `terraform/alerting_rules.tf` and `terraform/alerting_locals.tf`.

## WHERE TO LOOK

| Task                      | Location                                   | Notes                                            |
| ------------------------- | ------------------------------------------ | ------------------------------------------------ |
| **Datasource Config**     | `provisioning/datasources/datasources.yml` | Connection strings for Prometheus + ES           |
| **Dashboard Layouts**     | `dashboards/*.json`                        | Base JSON for visual design (16 dashboards)      |
| **Metric Scrapes**        | `tf-configs/prometheus.yml`                | Node-exporter targets & intervals                |
| **Alert Rules**           | `terraform/alerting_rules.tf`              | 14 rules in 3 groups (Terraform SSoT); locals in `alerting_locals.tf` |
| **Interpolated JSON**     | `tf-configs/*.json`                        | Rendered dashboards with injected host IPs       |
| **Log Collection Health** | `dashboards/log-collection-health.json`    | Filebeat coverage and ingestion rate monitoring  |
| **GlitchTip Bridge**      | `terraform/contact_points.tf`              | n8n contact point forwarding alerts to GlitchTip |
| **Logstash Metrics**      | `dashboards/logstash-metrics.json`         | Pipeline throughput, DLQ, exporter metrics       |

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
- **NO Local Alert Files**: Alert rules are Terraform-managed (`terraform/alerting_rules.tf`). Do not create standalone alert YAML files.
