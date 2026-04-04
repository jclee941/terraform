# AGENTS: 104-grafana/config — Grafana Runtime Configuration

## OVERVIEW
Runtime configuration files for Grafana LXC (104). Overrides and complements provisioning from `provisioning/`.

## STRUCTURE
```
config/
├── grafana.ini.tftpl      # Main config template
├── ldap.toml.tftpl        # LDAP auth config (if enabled)
└── alerting/              # Alert notification channels
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Server config | `grafana.ini.tftpl` | HTTP, security, analytics |
| Auth settings | `grafana.ini.tftpl` `[auth.*]` | Anonymous, proxy, LDAP |
| SMTP settings | `grafana.ini.tftpl` `[smtp]` | Alert email delivery |
| Unified alerting | `[unified_alerting]` | Grafana 8+ alerting system |

## CONVENTIONS
- Admin password from 1Password (no default)
- Anonymous access disabled
- Serve from sub-path disabled
- Allow embedding for HASS integration

## ANTI-PATTERNS
- NEVER commit admin credentials
- NEVER enable anonymous write access
- NEVER expose without reverse proxy
