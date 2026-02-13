# ELK Stack (LXC 105)

## OVERVIEW
Centralized logging stack for the homelab. Orchestrates **Elasticsearch** (v8.12.0), **Logstash** (ETL pipeline), **Kibana** (visualization), and **ElastAlert2** (alerting) to provide a unified telemetry sink. Ingests data from Filebeat agents across all containers and VMs.

## STRUCTURE
```
105-elk/
├── templates/                    # TF template sources (SSoT)
│   ├── docker-compose.yml.tftpl  # Full ELK stack definition
│   ├── logstash.conf.tftpl       # Logstash pipeline config
│   ├── logstash.yml.tftpl        # Logstash settings (DLQ, monitoring)
│   ├── filebeat.yml.tftpl        # Local filebeat config
│   ├── ilm-policy.json.tftpl     # Index Lifecycle Management policy
│   └── setup-ilm.sh.tftpl        # ILM bootstrap script
├── config/                       # Production config (reference/manual)
│   ├── logstash.conf             # Production logstash pipeline
│   ├── logstash.yml              # Production logstash settings
│   ├── Dockerfile.logstash       # Custom logstash with prometheus plugin
│   ├── elastalert.yaml           # ElastAlert2 base config
│   ├── elastalert-rules/         # Alert rule definitions
│   │   ├── critical-error-spike.yml
│   │   ├── high-error-rate.yml
│   │   ├── gateway-errors.yml
│   │   └── mcp-errors.yml
│   └── filebeat.yml              # Local filebeat config
├── scripts/                      # Operational scripts
│   ├── setup-ilm.sh              # ILM policy bootstrap
│   ├── install-filebeat.sh       # Filebeat installer
│   └── remove-promtail.sh        # Legacy cleanup
├── docker-compose.yml            # Production docker-compose (reference)
├── ilm-policy.json               # Production ILM policy (reference)
├── .env.example                  # Environment template
├── AGENTS.md                     # This file
├── BUILD.bazel
└── OWNERS
```

## WHERE TO LOOK
| Task | File Path |
|------|-----------|
| **Edit Pipeline** | `templates/logstash.conf.tftpl` (source) |
| **Alert Rules** | `config/elastalert-rules/*.yml` |
| **Docker Stack** | `templates/docker-compose.yml.tftpl` (source) |
| **Index Management** | `templates/ilm-policy.json.tftpl` (source) |
| **Logstash Settings** | `templates/logstash.yml.tftpl` (source) |
| **ILM Bootstrap** | `templates/setup-ilm.sh.tftpl` (source) |
| **Deployment** | `100-pve/main.tf` (cloud-init wiring) |

## TEMPLATE VARIABLES (from env-config module)
- `elk_ip`, `elk_ports.elasticsearch`, `elk_ports.kibana`, `elk_ports.logstash_beat`, `elk_ports.logstash_syslog`
- `elk_version` (8.12.0), `es_heap` (2g), `logstash_heap` (512m)
- `logstash_dlq_size` (1024mb), `elastalert_version` (2.19.0)
- `elasticsearch_index_pattern` (logs-%{+YYYY.MM.dd})
- `ilm_delete_after` (30d), `ilm_policy_name` (homelab-logs-30d)

## CONFIG PIPELINE
`templates/*.tftpl` → `config-renderer` module → `100-pve/configs/elk/` (local_sensitive_file) → cloud-init `write_files` → LXC `/opt/elk/`

## CONVENTIONS
- **ILM Policy**: All indices governed by `ilm-policy.json`. Standard retention: 30 days.
- **DLQ**: Enabled by default (1024mb max) to capture failed document mappings.
- **Resource Limits**: ES 4G/2cpu, Logstash 1G/1cpu, Kibana 1G/0.5cpu, ElastAlert 256M/0.25cpu.
- **Naming**: Use `logs-{service}-{env}` prefix for automatic pattern matching in Kibana.
- **Alerting**: ElastAlert2 → GlitchTip (Sentry SDK format) via http_post.

## ANTI-PATTERNS
- **NO Public 9200**: Elasticsearch API must never be exposed beyond `192.168.50.0/24`.
- **NO Manual Config Updates**: Do not hand-edit `tf-configs/` or use Kibana Console for settings.
- **NO Single-Point-of-Failure**: Do not disable ILM rollover (risk of disk saturation).
- **NO Plaintext Secrets**: GlitchTip/Sentry keys via Docker env vars only.

## COMMANDS
```bash
# Verify ES Health
curl localhost:9200/_cluster/health?pretty

# Test Logstash Pipeline
docker exec -it elk-logstash-1 bin/logstash -t -f /etc/logstash/conf.d/logstash.conf

# Restart Stack
docker compose -f /opt/elk/docker-compose.yml restart

# Run ILM Setup
bash /opt/elk/scripts/setup-ilm.sh
```
