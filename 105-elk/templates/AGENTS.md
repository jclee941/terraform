# AGENTS: 105-elk/templates — ELK Service Templates

## OVERVIEW
Terraform templates for ELK stack configuration. Rendered into Logstash pipelines and ES/Kibana configs.

## STRUCTURE
```
templates/
├── Dockerfile.logstash.tftpl # Custom Logstash image
├── docker-compose.yml.tftpl  # Stack deployment
├── filebeat.yml.tftpl        # Log forwarding config
├── ilm-policy.json.tftpl     # ILM bootstrap policy
├── logstash.conf.tftpl       # Main Logstash pipeline
├── logstash.yml.tftpl        # Logstash settings
└── setup-ilm.sh.tftpl        # ILM bootstrap script
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Logstash pipeline | `logstash.conf.tftpl` | beats → filter → elasticsearch |
| Stack compose | `docker-compose.yml.tftpl` | Elasticsearch, Kibana, Logstash, exporter wiring. |
| Logstash settings | `logstash.yml.tftpl` | Pipeline and monitoring settings. |
| ILM setup | `ilm-policy.json.tftpl`, `setup-ilm.sh.tftpl` | Index lifecycle bootstrap. |
| Grok patterns | `logstash.conf.tftpl` | Custom patterns for services |

## CONVENTIONS
- Use `beats { port => 5044 }` for Filebeat input
- Keep Elasticsearch auth assumptions aligned with `105-elk/terraform/onepassword.tf`.
- Keep Cloudflare Worker traces routed to `logs-cloudflare-workers-*`.

## ANTI-PATTERNS
- NEVER use `stdout { codec => rubydebug }` in production
- NEVER store parsed fields in `_source` unnecessarily
- NEVER let grok patterns fail silently — use tag_on_failure
