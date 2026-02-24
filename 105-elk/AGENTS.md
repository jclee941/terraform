# ELK Stack (LXC 105)

## OVERVIEW

Centralized logging stack for the homelab. Orchestrates **Elasticsearch** (v8.17.0), **Logstash** (ETL pipeline with exporter sidecar), and **Kibana** (visualization). Ingests data from **Filebeat** agents deployed across all 7 LXC containers, VM 112 (mcphub), and PVE bare-metal host (100) via Docker autodiscovery and filestream inputs. **Synology NAS** (215) forwards via syslog. **Cloudflare Logpush** sends Worker trace events via HTTP input (port 8080). **YouTube VM** (220) runs Filebeat when active. Alerting is handled by Grafana (104-grafana).

## STRUCTURE

```
105-elk/
├── templates/          # TF template sources (SSoT) — 9 tftpl files
├── config/             # Production config (reference/manual)
├── scripts/            # Operational (ILM bootstrap, filebeat install, promtail cleanup)
├── terraform/          # Standalone elasticstack provider workspace (tfstate tracked in git)
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
| **ILM Bootstrap**          | `scripts/setup-ilm.sh`, `templates/setup-ilm.sh.tftpl`             |
| **Filebeat Setup**         | `scripts/install-filebeat.sh`                                      |
| **Deployment**             | `100-pve/main.tf` (cloud-init wiring + filebeat provisioner)       |
| **ELK Provider Resources** | `terraform/main.tf` (ILM, index templates, Kibana spaces)          |
| **ELK Provider Outputs**   | `terraform/outputs.tf` (exported state for downstream consumers)   |

## TEMPLATE VARIABLES (from env-config module)

- `elk_ip`, `elk_ports.elasticsearch`, `elk_ports.kibana`, `elk_ports.logstash_beat`, `elk_ports.logstash_syslog`, `elk_ports.logstash_http`
- `elk_version` (8.17.0), `es_heap` (2g), `logstash_heap` (512m)
- `logstash_dlq_size` (1024mb)
- `elasticsearch_index_pattern` (logs-{service}-YYYY.MM.dd)
- `ilm_delete_after` (30d), `ilm_policy_name` (homelab-logs-30d)
- `elk_elastic_password`, `elk_kibana_password` (from 1Password `homelab/elk`)

## CONFIG PIPELINE

`templates/*.tftpl` → `config-renderer` module → `100-pve/configs/elk/` (local_sensitive_file) → cloud-init `write_files` → LXC `/opt/elk/`

## CONVENTIONS

- **2-Tier ILM**: Service indices use tiered lifecycle: hot (active writes, priority 100) → delete (configurable retention: 30d default, 90d critical, 7d ephemeral). No warm phase.
- **Logstash Exporter**: Sidecar container exposes Logstash metrics at `:9198/metrics` for Prometheus scraping.
- **Filebeat Autodiscovery**: All LXC hosts run Filebeat with Docker autodiscovery. New containers are auto-indexed via `logs-{service}-YYYY.MM.dd` pattern.
- **Service Index Split**: Each service gets a dedicated daily index (`logs-{service}-YYYY.MM.dd`) for independent ILM lifecycle and Kibana filtering. Three tiers: `logs-critical` (archon/elk/supabase/grafana/pve, 90d), `logs-ephemeral` (unknown/debug/runner/youtube, 7d), `logs-template` (everything else, 30d). Synology syslog is routed to `logs-synology-*` (default 30d tier).
- **DLQ**: Enabled by default (1024mb max) to capture failed document mappings.
- **Resource Limits**: ES 4G/2cpu, Logstash 1G/1cpu, Kibana 1G/0.5cpu.
- **Naming**: Index pattern is `logs-{service}-YYYY.MM.dd`. Service is extracted by Logstash from filebeat fields, Docker Compose labels, or parsed JSON. Fallback: `unknown`.
- **HTTP Ingest**: Logstash listens on port 8080 (`http` input, `json_lines` codec) for external log sources. Cloudflare Logpush Worker traces are routed to `logs-cloudflare-workers-*` with error classification on non-ok Outcome.
- **Alerting**: Grafana (`104-grafana/terraform/main.tf`) handles all alerting. ElastAlert2 was removed.
- **Script Alignment**: Keep operational scripts aligned with Terraform-defined service topology.
- **State Tracking**: `terraform/terraform.tfstate` is committed to git (exception to global rule) for CI apply reliability with elasticstack provider.
- **Terraform Secret Source**: `terraform/` provider auth password resolves from `module.onepassword_secrets` (`onepassword_vault_name` default `homelab`), not tfvars plaintext.

## SECURITY

- **xpack.security**: Enabled with HTTP basic auth (no TLS for internal network).
- **Credentials**: Stored in 1Password at `homelab/elk` with fields `elastic_password` and `kibana_password`.
- **Setup Container**: `elk-setup` runs once to set `kibana_system` password via ES Security API.
- **Auth Flow**: ES uses `ELASTIC_PASSWORD` env var; Kibana uses `kibana_system`; Logstash uses `elastic` for writes.
- **Traefik**: ES endpoint (`es.jclee.me`) restricted to LAN via `ipAllowList` middleware.

## ANTI-PATTERNS

- **NO Public 9200**: Elasticsearch API must never be exposed beyond `192.168.50.0/24`.
- **NO Manual Config Updates**: Do not hand-edit `tf-configs/` or use Kibana Console for settings.
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
