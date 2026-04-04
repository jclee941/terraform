# AGENTS: 107-supabase/templates — Supabase Configuration

## OVERVIEW
Terraform templates for Supabase deployment (LXC 107). Self-hosted Firebase alternative.

## STRUCTURE
```
templates/
├── docker-compose.yml.tftpl  # Supabase stack
├── config.toml.tftpl         # Supabase CLI config
└── .env.tftpl                # Environment variables
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Stack definition | `docker-compose.yml.tftpl` | Kong, GoTrue, PostgREST, Realtime, Storage |
| CLI config | `config.toml.tftpl` | Project settings, API URLs |
| Secrets | `.env.tftpl` | JWT secrets, DB passwords, SMTP |

## CONVENTIONS
- Use `module.hosts` for internal service URLs
- Postgres data persisted to host volume
- Kong gateway on port 8000 (HTTP), 8443 (HTTPS)

## ANTI-PATTERNS
- NEVER commit `.env` files with real secrets
- NEVER expose Postgres port 5432 publicly
- NEVER use default JWT secrets — generate strong keys
