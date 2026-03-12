# 110-n8n

n8n Workflow Automation — dedicated LXC workspace.

## Overview

LXC 110 runs n8n with a PostgreSQL sidecar, enterprise license patches,
cAdvisor for container metrics, and postgres-exporter for DB metrics.
Filebeat ships logs to the shared ELK stack.

## Structure

```text
110-n8n/
├── AGENTS.md
├── Dockerfile.n8n              # Custom image with enterprise license patches
├── patches/n8n/
│   ├── license.js              # Enterprise license enablement patch
│   └── license-state.js        # License state override patch
└── templates/
    ├── docker-compose.yml.tftpl  # n8n + postgres + cadvisor + pg-exporter
    ├── n8n.env.tftpl             # Environment variables (PG connection, secrets)
    └── filebeat.yml.tftpl        # Log shipping to ELK
```

## Runtime

| Container          | Image                       | Port  | Purpose                  |
|--------------------|-----------------------------|-------|--------------------------|
| n8n                | Custom (Dockerfile.n8n)     | 5678  | Workflow engine           |
| n8n-postgres       | postgres:16-alpine          | 5432  | Primary datastore         |
| n8n-cadvisor       | gcr.io/cadvisor/cadvisor    | 8888  | Container metrics         |
| n8n-postgres-exporter | prometheuscommunity/postgres-exporter | 9187 | PG metrics |

## Conventions

- All IPs flow from `module.hosts.hosts.n8n.ip` — never hardcode.
- Secrets come from 1Password via `modules/shared/onepassword-secrets`:
  `n8n_postgres_password`, `n8n_encryption_key`.
- Templates are rendered by `100-pve` config_renderer and deployed via LXC config.
- Enterprise patches are verbatim copies from `112-mcphub/patches/n8n/`.
- PostgreSQL data persists in a named Docker volume (`n8n_postgres_data`).

## Dependencies

- `100-pve`: LXC provisioning, firewall, config rendering.
- `102-traefik`: Reverse proxy routing (`n8n.yml.tftpl`).
- `104-grafana`: Prometheus scrape targets (cadvisor, postgres-exporter, blackbox).
- `112-mcphub`: MCPhub `.env` references `N8N_MCP_API_URL` pointing to this host.

## Anti-Patterns

- Do not hardcode `192.168.50.110` in templates; use `${hosts.n8n.ip}`.
- Do not hand-edit files on the LXC; redeploy via Terraform.
- Do not modify enterprise patches without syncing with `112-mcphub` copies.
- Do not expose PostgreSQL port (5432) beyond the LXC — firewall excludes it.
