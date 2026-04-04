# AGENTS: 105-elk/config — ELK Stack Configuration

## OVERVIEW
Configuration files for ELK stack (LXC 105): Elasticsearch, Logstash, Kibana.

## STRUCTURE
```
config/
├── elasticsearch.yml      # ES cluster config
├── logstash.conf          # Logstash pipeline
├── kibana.yml             # Kibana server config
└── filebeat/              # Reference Filebeat configs
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| ES cluster | `elasticsearch.yml` | Single node, 192.168.50.105 |
| Logstash pipeline | `logstash.conf` | Beats input → filter → ES output |
| Kibana server | `kibana.yml` | ES connection, server.host |
| ILM policies | `elasticsearch.yml` | Index lifecycle management |

## CONVENTIONS
- Single-node cluster for homelab scale
- Logstash listens on 5044 (Beats), 9600 (API)
- Kibana behind Traefik at elk.jclee.me

## ANTI-PATTERNS
- NEVER expose ES port 9200 publicly
- NEVER use default elastic/changeme credentials
- NEVER let indices grow unbounded — use ILM
