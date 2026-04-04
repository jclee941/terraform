# AGENTS: 104-grafana/templates — Grafana Service Templates

## OVERVIEW
Terraform templates for Grafana service configuration. Rendered by `100-pve` into LXC 104.

## STRUCTURE
```
templates/
├── grafana.ini.tftpl      # Main Grafana config
└── provisioning/          # Provisioning templates
    ├── datasources.yml.tftpl
    └── dashboards.yml.tftpl
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Server settings | `grafana.ini.tftpl` | domain, root_url, serve_from_sub_path |
| Security | `grafana.ini.tftpl` | admin_password, secret_key |
| Datasources | `provisioning/datasources.yml.tftpl` | Prometheus, Loki, ES |

## CONVENTIONS
- Use `module.hosts` for datasource URLs
- Secrets from 1Password via template variables
- Provisioning path: `/etc/grafana/provisioning/`

## ANTI-PATTERNS
- NEVER hardcode passwords in templates
- NEVER use default admin/admin credentials
