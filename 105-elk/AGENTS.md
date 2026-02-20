# ELK Stack (LXC 105)

## OVERVIEW
Centralized logging stack for the homelab. Orchestrates **Elasticsearch** (v8.17.0), **Logstash** (ETL pipeline), and **Kibana** (visualization) to provide a unified telemetry sink. Ingests data from Filebeat agents across all containers and VMs. Alerting is handled by Grafana (104-grafana).

## STRUCTURE
```
105-elk/
├── templates/          # TF template sources (SSoT) — 7 tftpl files
├── config/             # Production config (reference/manual)
├── scripts/            # Operational (ILM bootstrap, filebeat install, promtail cleanup)
├── terraform/          # Standalone elasticstack provider workspace
├── docker-compose.yml  # Production stack (reference)
└── .env.example        # Environment template
```

## WHERE TO LOOK
| Task | File Path |
|------|-----------|
| **Edit Pipeline** | `templates/logstash.conf.tftpl` (source) |
| **Docker Stack** | `templates/docker-compose.yml.tftpl` (source) |
| **Index Management** | `templates/ilm-policy.json.tftpl` (source) |
| **Logstash Settings** | `templates/logstash.yml.tftpl` (source) |
| **ILM Bootstrap** | `scripts/setup-ilm.sh` |
| **Filebeat Setup** | `scripts/install-filebeat.sh` |
| **Deployment** | `100-pve/main.tf` (cloud-init wiring) |
| **ELK Provider Resources** | `terraform/main.tf` (ILM, index templates, Kibana spaces) |

## TEMPLATE VARIABLES (from env-config module)
- `elk_ip`, `elk_ports.elasticsearch`, `elk_ports.kibana`, `elk_ports.logstash_beat`, `elk_ports.logstash_syslog`
- `elk_version` (8.12.0), `es_heap` (2g), `logstash_heap` (512m)
- `logstash_dlq_size` (1024mb)
- `elasticsearch_index_pattern` (logs-%{+YYYY.MM.dd})
- `ilm_delete_after` (30d), `ilm_policy_name` (homelab-logs-30d)
- `elk_elastic_password`, `elk_kibana_password` (from 1Password `homelab/elk`)

## CONFIG PIPELINE
`templates/*.tftpl` → `config-renderer` module → `100-pve/configs/elk/` (local_sensitive_file) → cloud-init `write_files` → LXC `/opt/elk/`

## CONVENTIONS
- **ILM Policy**: All indices governed by `ilm-policy.json`. Standard retention: 30 days.
- **DLQ**: Enabled by default (1024mb max) to capture failed document mappings.
- **Resource Limits**: ES 4G/2cpu, Logstash 1G/1cpu, Kibana 1G/0.5cpu.
- **Naming**: Use `logs-{service}-{env}` prefix for automatic pattern matching in Kibana.
- **Alerting**: Grafana (104-grafana/alerting.yaml) handles all alerting. ElastAlert2 was removed.
- **Script Alignment**: Keep operational scripts aligned with Terraform-defined service topology.

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
- **NO Plaintext Secrets**: GlitchTip/Sentry keys via Docker env vars only.
- **NO Disabling xpack.security**: Once enabled, do not disable; all clients depend on auth.
- **NO Untargeted Scripts**: Do not run migration/cleanup scripts on unintended hosts.

## COMMANDS
```bash
curl -u elastic:$ELASTIC_PASSWORD localhost:9200/_cluster/health?pretty  # ES health
docker exec -it logstash bin/logstash -t -f /usr/share/logstash/pipeline/logstash.conf  # Test pipeline
docker compose -f /opt/elk/docker-compose.yml restart  # Restart stack
bash /opt/elk/scripts/setup-ilm.sh  # ILM bootstrap
```
