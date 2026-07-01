# AGENTS: 102-traefik/config — Traefik Static Configuration

## OVERVIEW
Static configuration files for Traefik reverse proxy (LXC 102). Complements dynamic routes rendered from templates.

## STRUCTURE
```
config/
├── traefik.yml            # Static config: entrypoints/providers
├── middlewares.yml        # Static middleware definitions
└── filebeat.yml           # Log forwarding config
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Entrypoints | `traefik.yml` | HTTP (80), HTTPS (443), Dashboard (8080) |
| Providers | `traefik.yml` | File provider for dynamic routes |
| Middleware | `middlewares.yml` | Static middleware definitions. |
| Log forwarding | `filebeat.yml` | Traefik logs to ELK. |

## CONVENTIONS
- Static config in `config/`, dynamic routes in `templates/`
- Use `file` provider pointing to `/opt/traefik/dynamic/`
- Dashboard disabled or secured by IP whitelist

## ANTI-PATTERNS
- NEVER commit TLS private keys
- NEVER expose dashboard without auth
- NEVER use self-signed certs in production
