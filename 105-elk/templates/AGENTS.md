# AGENTS: 105-elk/templates — ELK Service Templates

## OVERVIEW
Terraform templates for ELK stack configuration. Rendered into Logstash pipelines and ES/Kibana configs.

## STRUCTURE
```
templates/
├── logstash.conf.tftpl    # Main Logstash pipeline
├── elasticsearch.yml.tftpl # Elasticsearch settings
├── kibana.yml.tftpl       # Kibana settings
└── pipelines/             # Additional pipeline definitions
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Logstash pipeline | `logstash.conf.tftpl` | beats → filter → elasticsearch |
| ES settings | `elasticsearch.yml.tftpl` | cluster.name, network.host |
| Kibana settings | `kibana.yml.tftpl` | elasticsearch.hosts, server.host |
| Grok patterns | `logstash.conf.tftpl` | Custom patterns for services |

## CONVENTIONS
- Use `beats { port => 5044 }` for Filebeat input
- ES output: `hosts => ["localhost:9200"]`
- Index naming: `%{[@metadata][beat]}-%{[@metadata][version]}-%{+YYYY.MM.dd}`

## ANTI-PATTERNS
- NEVER use `stdout { codec => rubydebug }` in production
- NEVER store parsed fields in `_source` unnecessarily
- NEVER let grok patterns fail silently — use tag_on_failure
