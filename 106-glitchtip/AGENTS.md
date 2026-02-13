# PROJECT KNOWLEDGE BASE: 106-GLITCHTIP

**Generated:** 2026-02-12
**VMID:** 106
**IP:** 192.168.50.106
**Style:** Google3 Monorepo (Bazel)

## OVERVIEW
GlitchTip Error Tracking Service. Open-source, self-hosted **Sentry alternative** for error tracking. Aggregates application exceptions, performance metrics, and uptime monitoring for the `jclee.me` homelab. Managed as a Proxmox LXC.

## STRUCTURE
Orchestrated via **Docker Compose** with Terraform-rendered configs.
```
106-glitchtip/
├── tf-configs/         # Terraform-rendered outputs (DO NOT EDIT)
│   ├── docker-compose.yml
│   └── glitchtip.env
├── templates/          # Source templates for Terraform rendering
│   ├── docker-compose.yml.tftpl
│   └── glitchtip.env.tftpl
├── config/             # Service-specific configurations
│   └── filebeat.yml    # Log forwarding to ELK (105)
├── BUILD.bazel         # Bazel target definitions
└── OWNERS              # Directory ownership
```

## WHERE TO LOOK
| Component | Location | Notes |
|-----------|----------|-------|
| **Deployment** | `tf-configs/docker-compose.yml` | Managed via Terraform |
| **Environment** | `tf-configs/glitchtip.env` | Secrets sourced from Vault |
| **Ingress** | `102-traefik/config/glitchtip.yml` | Reverse proxy routing |
| **Automation** | `112-mcphub/n8n-workflows/` | Error to GitHub Issue pipelines |

## CONVENTIONS
- **Governance**: Managed by Terraform. Do not use GlitchTip UI for infrastructure settings.
- **Secrets**: High-entropy secrets (Postgres/Redis passwords) are fetched from Vault Agent (VM 112).
- **User Registration**: `ENABLE_USER_REGISTRATION` is set to `false`. Admin accounts must be created via Django CLI.
- **Alerting**: Configured via `n8n-automation` rule sending webhooks to n8n (112).
- **Log Source**: Sentry SDKs point to `https://glitchtip.jclee.me`.

## ANTI-PATTERNS
- **NO Plaintext Secrets**: NEVER commit actual credentials to `.env` or `.tftpl` files.
- **NO Manual Config Tweaks**: Any change to `docker-compose.yml` or `.env` MUST be done via Terraform to prevent drift.
- **NO Direct SSH**: Access strictly via `pct exec 106 -- bash` from the PVE host.
- **NO Direct DB Access**: Use the GlitchTip API or standard backup tools.

## COMMANDS
```bash
# Enter container environment
pct enter 106

# View real-time service logs
docker compose logs -f

# Create a new superuser account
docker compose exec web ./manage.py createsuperuser
```

