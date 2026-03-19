# 102-traefik: Edge Ingress & Reverse Proxy

## 1. Service Overview
- **Service Name**: Traefik Proxy
- **Host IP**: `192.168.50.102` (LXC)
- **Purpose**: High-performance reverse proxy and load balancer. It serves as the single entry point for all `jclee.me` subdomains and internal services.
- **Current Status**: **Online**. Handling ingress for Grafana, n8n, and the MCP cluster.
- **Hardware Profile**: 
  - **Memory Usage**: ~28.8%
  - **CPU Usage**: ~0.1% (Idle)

## 2. Configuration Files
Traefik uses a combination of static and dynamic configurations:
- **Static Config**: `/etc/traefik/traefik.yml` - Defines entrypoints (80, 443, 8080), providers, and log levels.
- **Dynamic Config (File Provider)**: `/opt/traefik/config/`
  - `mcp.yml`: Routing rules for 17+ MCP services (SSE/HTTP).
  - `middlewares.yml`: Definitions for `mcp-resilient` (retry, circuit-breaker) and security headers.
  - `jclee.me.yml`: Main host-based routing for primary subdomains.
- **SSL Certificates**: Managed via Let's Encrypt (ACME) stored in `/etc/traefik/acme.json`.

## 3. Operations
### Lifecycle Commands
```bash
# SSH into Traefik container
ssh traefik

# Check Service Status
systemctl status traefik

# Verify Configuration & Health
traefik healthcheck

# Debug Routing (API)
curl localhost:8080/api/http/routers | jq
curl localhost:8080/api/http/services | jq
```

### Logging
- **Access Logs**: `/var/log/traefik/access.log` (shipped via Filebeat → ELK)
- **Error Logs**: `journalctl -u traefik -f`

## 4. Dependencies
Traefik is the critical path for:
- **104-grafana**: https://grafana.jclee.me
- **105-elk**: https://kibana.jclee.me
- **112-mcphub**: https://mcphub.jclee.me
- **112-mcphub** (n8n): https://n8n.jclee.me

It depends on:
- **Local DNS**: Requires correct A/CNAME records pointing to `.102`.
- **Certificates**: Depends on Let's Encrypt API for HTTPS verification.

## 5. Troubleshooting
### Common Issues
- **502 Bad Gateway**: The backend service (e.g., Supabase or ELK) is down.
  - *Fix*: Check the status of the target LXC/VM.
- **404 Not Found**: Routing rule mismatch.
  - *Fix*: Verify the `Host` header in `/opt/traefik/config/*.yml`.
- **Certificate Errors**: ACME challenge failing (usually DNS/Firewall issue).
  - *Fix*: Check `traefik.log` for ACME challenge status.
- **MCP Service Unreachable**: `mcp-resilient` circuit breaker might be open.
  - *Fix*: Check MCP server health on `.112` (MCPHub).

## 6. Routing Pattern
- **Host-based**: `{service}.jclee.me` → backend service.
- **MCP Services**: `mcp.jclee.me/{server}` → MCPHub (192.168.50.112).
- **Middleware Chain**: All MCP routes MUST use `mcp-resilient` chain (retry-5 + circuit-breaker).

## 7. Governance
- **Style**: Google3 Monorepo
- **Ownership**: Infrastructure Team
