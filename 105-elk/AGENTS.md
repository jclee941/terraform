# ELK Stack (LXC 105)

## OVERVIEW
Centralized logging stack for the homelab. Orchestrates **Elasticsearch** (v8.x storage engine) and **Logstash** (ETL pipeline) to provide a unified telemetry sink. Ingests data from Filebeat agents across all containers and VMs.

## STRUCTURE (Pipeline Config)
Logstash logic is modularized to ensure maintainable transformations.
- `config/logstash.conf`: Global pipeline entry point defining beats input (5044) and classification logic.
- `config/logstash.yml`: Global settings (queue type, memory limits).
- `tf-configs/`: Environment-rendered configs. No manual edits allowed.
- `templates/`: Source jinja templates for configuration rendering.

## WHERE TO LOOK
| Task | File Path |
|------|-----------|
| **Edit Pipeline** | `config/logstash.conf` |
| **Alert Rules** | `config/elastalert-rules/*.yml` |
| **Manage ES Indexes** | `config/ilm-policy.json` |
| **Deployment** | `docker-compose.yml` |

## CONVENTIONS (ILM Policies)
- **ILM Policy**: All indices are governed by `ilm-policy.json`. Standard retention: 30 days.
- **Rollover**: Hot indices roll over at 50GB or 30 days to prevent large shard overhead.
- **Naming**: Use `logs-{service}-{env}` prefix for automatic pattern matching in Kibana.
- **Dead Letter Queue (DLQ)**: Enabled by default to capture failed document mappings.

## ANTI-PATTERNS
- **NO Public 9200**: Port 9200 (Elasticsearch API) must never be exposed beyond the internal `192.168.50.0/24` subnet.
- **NO Manual Config Updates**: Do not use the Kibana Console for configuration changes; keep all logic in `logstash.conf`.
- **NO Single-Point-of-Failure**: Do not disable the `hot` phase rollover (risk of disk saturation).
- **NO Plaintext Secrets**: All GlitchTip/Sentry keys must be injected via Docker environment variables.

## COMMANDS
```bash
# Verify ES Health
curl localhost:9200/_cluster/health?pretty

# Test Logstash Pipeline
docker exec -it elk-logstash-1 bin/logstash -t -f /etc/logstash/conf.d/logstash.conf

# Restart Stack
docker compose -f /opt/elk/docker-compose.yml restart
```
