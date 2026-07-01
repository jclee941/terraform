# AGENTS: 102-traefik/templates — Traefik Dynamic Routes

## OVERVIEW
Dynamic routing templates for Traefik. Rendered per-service into YAML route definitions.

## STRUCTURE
```
templates/
├── cloudflared-docker-compose.yml.tftpl # Tunnel connector compose
├── filebeat.yml.tftpl                   # Log shipping config
├── mcphub.yml.tftpl                     # MCPHub route
├── middlewares.yml.tftpl                # Shared middleware definitions
├── minio.yml.tftpl                      # Registry/MinIO route
├── nas.yml.tftpl                        # Synology DSM route
├── registry.yml.tftpl                   # Registry route
└── traefik-elk.yml.tftpl                # ELK/Kibana/ES routes
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Route definition | `{service}.yml.tftpl` | Router, service, middleware chain |
| Middleware | `middlewares.yml.tftpl` | Rate limit, auth, headers, chain definitions. |
| Service target | Template variables | Use host map inputs, never literal backend IPs. |
| TLS cert | `tls: {}` or `certResolver` | Let's Encrypt or internal |

## CONVENTIONS
- One file per route family or shared middleware set.
- Router name: `{service}-{protocol}` where practical.
- Service name: `{service}-svc` where practical.
- Use `Host(`subdomain.jclee.me`)` for routing rules

## ANTI-PATTERNS
- NEVER hardcode IPs — use template variables
- NEVER use insecure endpoints without middleware
- NEVER duplicate route logic — use includes

## TEMPLATE VARIABLES
- `hosts` — host inventory map (from `module.hosts`)
- `service_fqdn` — full domain for the service
- `service_port` — backend port
