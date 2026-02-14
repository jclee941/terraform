# ADR-003: Cloudflare Tunnel for External Access

**Status:** Accepted  
**Date:** 2026-02-13  

## Context

The homelab runs behind NAT with no public IP. Services need to be accessible externally for development and monitoring.

## Decision

Use Cloudflare Tunnels for all external access:
- `homelab-traefik` tunnel: Routes `*.jclee.me` → Traefik:102 → internal services
- `synology-nas` tunnel: Routes `nas.jclee.me` → Synology:215
- Cloudflare Access policies for authentication
- Zero-trust model — no inbound ports open

## Alternatives Considered

1. **Port forwarding** — Exposes IP, requires static IP or DDNS
2. **WireGuard VPN** — Requires client setup, not browser-accessible
3. **Tailscale** — Good but adds another dependency layer
4. **ngrok** — Cost, reliability concerns for production

## Consequences

- Zero inbound firewall rules needed
- CF Access provides SSO/email-based auth
- All traffic proxied through Cloudflare (DDoS protection)
- Dependency on Cloudflare availability
- TF-managed: tunnel config, DNS, Access policies all in `300-cloudflare/`
- Workers can intercept tunnel traffic (synology-proxy for R2 caching)
