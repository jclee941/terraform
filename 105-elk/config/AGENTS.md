# AGENTS: 105-elk/config — ELK Stack Configuration

## OVERVIEW
Rendered/reference configuration files for ELK stack (LXC 105). Source edits usually belong in `../templates/`.

## STRUCTURE
```
config/
├── Dockerfile.logstash    # Rendered custom Logstash image
├── filebeat.yml           # Rendered Filebeat config
├── ilm-policy.json        # Rendered ILM policy
├── logstash.conf          # Rendered Logstash pipeline
└── logstash.yml           # Rendered Logstash settings
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Logstash pipeline | `logstash.conf` | Beats/HTTP inputs, filters, ES output. |
| Logstash settings | `logstash.yml` | Runtime settings. |
| ILM policy | `ilm-policy.json` | Index lifecycle policy. |
| Source templates | `../templates/AGENTS.md` | Edit templates, then render. |

## CONVENTIONS
- Treat files here as rendered/reference unless a runbook explicitly says otherwise.
- Logstash listens on 5044 (Beats), 8080 (HTTP ingest), and 9600 (API/exporter path).
- Kibana/Elasticsearch external access is through Traefik routes.

## ANTI-PATTERNS
- NEVER expose ES port 9200 publicly
- NEVER put credentials in rendered configs.
- NEVER let indices grow unbounded — use ILM
