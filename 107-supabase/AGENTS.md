# AGENTS: 107-supabase

> **Host**: LXC 107 | **IP**: 192.168.50.107 | **Status**: template-only

## OVERVIEW
Self-hosted Supabase instance providing PostgreSQL database, Auth, REST API, Realtime, and Storage services for the homelab infrastructure.

- **VMID**: 107
- **IP**: 192.168.50.107
- **Type**: LXC Container
- **Domain**: supabase.jclee.me (via Traefik)

## STRUCTURE
```
107-supabase/
├── BUILD.bazel          # Bazel governance
├── OWNERS               # Ownership
├── AGENTS.md            # This file
├── README.md            # Service documentation
├── templates/           # Config templates (rendered by Terraform)
└── tf-configs/          # TF-rendered configs (DO NOT hand-edit)
```

## WHERE TO LOOK
| Task | Location |
|------|----------|
| Service ports/IP | `100-pve/envs/prod/hosts.tf` (supabase entry) |
| LXC provisioning | `100-pve/main.tf` (module.supabase_lxc) |
| Docker compose | `templates/docker-compose.yml.tftpl` |
| Environment vars | `templates/.env.tftpl` |

## PORTS
| Port | Service |
|------|---------|
| 3000 | Supabase Studio (UI) |
| 8000 | Kong API Gateway |
| 5432 | PostgreSQL |
| 4000 | Realtime |
| 9000 | Inbucket (dev email) |

## CONVENTIONS
- All configs rendered via Terraform template pipeline
- Secrets managed via 1Password (`modules/shared/onepassword-secrets/`)
- No hardcoded credentials — use `.env.tftpl` templates
- PostgreSQL data persisted on local-zfs storage

## ANTI-PATTERNS
- **NO** manual docker-compose edits in `tf-configs/` — edit `templates/` instead
- **NO** direct database access from outside the homelab network
- **NO** hardcoded passwords — use 1Password
- **NO** UI changes to LXC resources (managed by Terraform)

## DEPENDENCIES
- **Upstream**: 108-archon (uses Supabase for vector storage + auth)
- **Downstream**: 102-traefik (reverse proxy), 104-grafana (monitoring)
