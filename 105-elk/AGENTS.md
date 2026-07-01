# AGENTS: 105-elk

## OVERVIEW

Centralized logging stack for the homelab. Orchestrates **Elasticsearch** (v8.17.0), **Logstash** (ETL pipeline with exporter sidecar), and **Kibana** (visualization). Ingests Filebeat, Synology syslog, and Cloudflare Logpush Worker trace events via HTTP input (port 8080). Alerting is handled outside this workspace; ElastAlert2 was removed.

## STRUCTURE

```
105-elk/
├── templates/          # TF template sources (SSoT) — 7 tftpl files
├── config/             # Production config (reference/manual)
├── scripts/            # Operational helpers (ILM, watcher, promtail cleanup)
├── terraform/          # Standalone elasticstack provider workspace
├── docker-compose.yml  # Production stack (reference)
└── .env.example        # Environment template
```

## WHERE TO LOOK

| Task                       | File Path                                                          |
| -------------------------- | ------------------------------------------------------------------ |
| **Edit Pipeline**          | `templates/logstash.conf.tftpl` (source)                           |
| **Docker Stack**           | `templates/docker-compose.yml.tftpl` (source)                      |
| **Index Management**       | `templates/ilm-policy.json.tftpl` (source)                         |
| **Logstash Settings**      | `templates/logstash.yml.tftpl` (source)                            |
| **Logstash Exporter**      | `templates/Dockerfile.logstash.tftpl` (custom image with exporter) |
| **ILM Bootstrap**          | `scripts/setup-ilm.go`, `templates/setup-ilm.sh.tftpl`              |
| **Filebeat Setup**         | `../scripts/install-filebeat.sh`, `100-pve/terraform/{lxc_configs,vm_configs}.tf` |
| **Deployment**             | `100-pve/terraform/main.tf` and config deploy modules              |
| **ELK Provider Resources** | `terraform/main.tf` (ILM, index templates, Kibana spaces)          |
| **ELK Provider Outputs**   | `terraform/outputs.tf` (exported state for downstream consumers)   |

## TEMPLATE VARIABLES (from env-config module)

- Variables: `elk_ip`, `elk_ports.*`, `elk_version` (8.17.0), `es_heap` (2g), `logstash_heap` (512m), `logstash_dlq_size` (1024mb), `elasticsearch_index_pattern`, `ilm_delete_after` (30d), `ilm_policy_name`. Credentials from 1Password `homelab/elk`.

## CONFIG PIPELINE

`templates/*.tftpl` → `config-renderer` module → `100-pve/terraform/configs/rendered/elk/` → config deploy modules → LXC `/opt/elk/`

## CONVENTIONS

- **2-Tier ILM**: Service indices use tiered lifecycle: hot (active writes, priority 100) → delete (configurable retention: 30d default, 90d critical, 7d ephemeral). No warm phase.
- **Logstash Exporter**: Sidecar container exposes Logstash metrics at `:9198/metrics` for Prometheus scraping.
- **Filebeat Autodiscovery**: All LXC hosts run Filebeat with Docker autodiscovery. New containers are auto-indexed via `logs-{service}-YYYY.MM.dd` pattern.
- **Service Index Split**: Each service gets a dedicated daily index (`logs-{service}-YYYY.MM.dd`) for independent ILM lifecycle and Kibana filtering. Three tiers: `logs-critical`, `logs-ephemeral`, and `logs-template`. Synology syslog is routed to `logs-synology-*`.
- **DLQ**: Enabled by default (1024mb max) to capture failed document mappings.
- **Resource Limits**: ES 4G/2cpu, Logstash 1G/1cpu, Kibana 1G/0.5cpu.
- **Naming**: Index pattern is `logs-{service}-YYYY.MM.dd`. Service is extracted by Logstash from filebeat fields, Docker Compose labels, or parsed JSON. Fallback: `unknown`.
- **HTTP Ingest**: Logstash listens on port 8080 (`http` input, `json_lines` codec) for external log sources. Cloudflare Logpush Worker traces are routed to `logs-cloudflare-workers-*` with error classification on non-ok Outcome.
- **Alerting**: Alerting is external to this workspace. ElastAlert2 was removed.
- **State Tracking**: `.tfstate` files are ignored; do not commit local Elastic provider state.
- **Terraform Secret Source**: `terraform/` provider auth password resolves from `module.onepassword_secrets` (`onepassword_vault_name` default `homelab`), not tfvars plaintext.

## SECURITY

- **xpack.security**: Enabled with HTTP basic auth (no TLS for internal). Credentials in 1Password `homelab/elk` (`elastic_password`, `kibana_password`).
- **Auth Flow**: `elk-setup` container bootstraps `kibana_system`. ES uses `ELASTIC_PASSWORD` env var; Kibana uses `kibana_system`; Logstash uses `elastic`.
- **Traefik**: `es.jclee.me` restricted to LAN via `ipAllowList` middleware.

## ANTI-PATTERNS

- **NO Public 9200**: Elasticsearch API must never be exposed beyond `192.168.50.0/24`.
- **NO Manual Config Updates**: Do not hand-edit rendered configs or use Kibana Console for settings.
- **NO Single-Point-of-Failure**: Do not disable ILM rollover (risk of disk saturation).
- **NO Plaintext Secrets**: Keep Terraform provider credentials 1Password-backed. tfvars secret overrides are break-glass only during active incident response, must be time-boxed, and require same-day rollback to 1Password source.
- **NO Disabling xpack.security**: Once enabled, do not disable; all clients depend on auth.
- **NO Untargeted Scripts**: Do not run migration/cleanup scripts on unintended hosts.
- **NO Disabling Logstash Exporter**: Prometheus alerting depends on exporter metrics.

## COMMANDS

```bash
curl -u elastic:$ELASTIC_PASSWORD localhost:9200/_cluster/health?pretty  # ES health
curl -s localhost:9198/metrics | head -20  # Logstash exporter metrics
docker exec -it logstash bin/logstash -t -f /usr/share/logstash/pipeline/logstash.conf  # Test pipeline
docker compose -f /opt/elk/docker-compose.yml restart  # Restart stack
bash /opt/elk/scripts/setup-ilm.sh  # ILM bootstrap
```
