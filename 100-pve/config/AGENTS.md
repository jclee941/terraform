# AGENTS: 100-pve/config — Host-Level Filebeat Configuration

## OVERVIEW
Filebeat configuration templates for PVE host (hypervisor) log shipping to ELK.

## STRUCTURE
```
config/
└── filebeat.yml           # Host Filebeat configuration
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Filebeat setup | `filebeat.yml` | PVE host log shipping |
| Log paths | `filebeat.yml` | `/var/log/pve*/`, `/var/log/syslog` |

## CONVENTIONS
- Ship to Logstash on LXC 105:5044
- Add `fields: {env: production}`
- Use `add_host_metadata` processor

## ANTI-PATTERNS
- NEVER use Elasticsearch output directly — use Logstash
- NEVER ship without log rotation handling
