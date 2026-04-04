# AGENTS: 104-grafana/provisioning — Grafana Auto-Provisioning

## OVERVIEW
Grafana provisioning configs for datasources and dashboards. Loaded automatically on startup.

## STRUCTURE
```
provisioning/
├── datasources/
│   └── datasources.yml    # Prometheus, Loki, Tempo, etc.
└── dashboards/
    └── dashboards.yml     # Dashboard providers
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Prometheus DS | `datasources/datasources.yml` | http://192.168.50.104:9090 |
| Loki DS | `datasources/datasources.yml` | http://192.168.50.105:3100 |
| Elasticsearch DS | `datasources/datasources.yml` | http://192.168.50.105:9200 |
| Dashboard loading | `dashboards/dashboards.yml` | Path: `/var/lib/grafana/dashboards/` |

## CONVENTIONS
- Datasources: YAML list, one entry per source
- Dashboards: JSON files in host-mounted volume
- Editable: false (prevent UI changes — use IaC)

## ANTI-PATTERNS
- NEVER mix datasource YAML with dashboard JSON
- NEVER use UI-saved dashboards in production
- NEVER hardcode auth tokens — use 1Password
