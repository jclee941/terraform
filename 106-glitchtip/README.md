# 106-glitchtip

Self-hosted GlitchTip error tracking service (Sentry alternative) for the jclee.me homelab.

## Services

- **GlitchTip Web** (8000) — Error tracking UI and API
- **PostgreSQL** (5432) — Event storage
- **Redis** (6379) — Cache and task queue
- **Celery Worker** — Background task processing

## Access

- Web UI: https://glitchtip.jclee.me

## Management

Managed by Terraform via `100-pve/main.tf`. See `AGENTS.md` for conventions.
