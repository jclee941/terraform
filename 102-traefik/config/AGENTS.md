# AGENTS: 102-traefik/config — Traefik Static Configuration

## OVERVIEW
Static configuration files for Traefik reverse proxy (LXC 102). Complements dynamic routes rendered from templates.

## STRUCTURE
```
config/
├── traefik.yml            # Static config: entrypoints, providers, TLS
├── tls/                   # TLS certificate configs
└── middleware/            # Global middleware definitions
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Entrypoints | `traefik.yml` | HTTP (80), HTTPS (443), Dashboard (8080) |
| Providers | `traefik.yml` | File provider for dynamic routes |
| TLS defaults | `tls/` | Default cert resolver, options |
| Middleware | `middleware/` | Rate limit, auth, headers |

## CONVENTIONS
- Static config in `config/`, dynamic routes in `templates/`
- Use `file` provider pointing to `/opt/traefik/dynamic/`
- Dashboard disabled or secured by IP whitelist

## ANTI-PATTERNS
- NEVER commit TLS private keys
- NEVER expose dashboard without auth
- NEVER use self-signed certs in production
