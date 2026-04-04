# AGENTS: 102-traefik/templates — Traefik Dynamic Routes

## OVERVIEW
Dynamic routing templates for Traefik. Rendered per-service into YAML route definitions.

## STRUCTURE
```
templates/
├── dashboard.yml.tftpl    # Traefik dashboard route (restricted)
├── grafana.yml.tftpl      # Grafana route
├── elk.yml.tftpl          # Kibana route
├── archon.yml.tftpl       # Archon route
├── n8n.yml.tftpl          # n8n route
├── mcphub.yml.tftpl       # MCPHub route
└── *.yml.tftpl            # Service-specific routes
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Route definition | `{service}.yml.tftpl` | Router, service, middleware chain |
| Middleware | inline or `config/middleware/` | Rate limit, auth, stripPrefix |
| Service target | `http://IP:port` | Use `module.hosts.hosts[name].ip` |
| TLS cert | `tls: {}` or `certResolver` | Let's Encrypt or internal |

## CONVENTIONS
- One file per service route
- Router name: `{service}-{protocol}` (e.g., `grafana-https`)
- Service name: `{service}-svc`
- Use `Host(`subdomain.jclee.me`)` for routing rules

## ANTI-PATTERNS
- NEVER hardcode IPs — use template variables
- NEVER use insecure endpoints without middleware
- NEVER duplicate route logic — use includes

## TEMPLATE VARIABLES
- `hosts` — host inventory map (from `module.hosts`)
- `service_fqdn` — full domain for the service
- `service_port` — backend port
