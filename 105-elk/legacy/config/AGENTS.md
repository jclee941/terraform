# AGENTS: 105-elk/legacy/config — Archived ELK Stack Configuration

## OVERVIEW
Inactive configuration snapshots retained for historical comparison. Active source edits belong in `../../templates/`.

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
| Active source templates | `../../templates/AGENTS.md` | Edit templates, then render. |

## CONVENTIONS
- Treat every file here as archived and non-deployable.
- Logstash listens on 5044 (Beats), 8080 (HTTP ingest), and 9600 (API/exporter path).
- Kibana/Elasticsearch external access uses direct Cloudflare Tunnel origins.

## ANTI-PATTERNS
- NEVER expose ES port 9200 publicly
- NEVER use these snapshots as deployment input.
- NEVER put credentials in rendered configs.
- NEVER let indices grow unbounded — use ILM
