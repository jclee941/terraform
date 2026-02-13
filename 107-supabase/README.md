# 107-supabase

Self-hosted Supabase instance for the jclee.me homelab.

## Services
- **PostgreSQL** (5432) — Primary database
- **Kong API Gateway** (8000) — REST/GraphQL API
- **Supabase Studio** (3000) — Web UI
- **Realtime** (4000) — WebSocket subscriptions
- **Inbucket** (9000) — Dev email testing

## Access
- Studio: https://supabase.jclee.me
- API: https://supabase-api.jclee.me

## Management
Managed by Terraform via `100-pve/main.tf`. See `AGENTS.md` for conventions.
