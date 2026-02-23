# 103-coredns

Split DNS resolver for internal homelab clients.

Resolves `*.jclee.me` → `192.168.50.102` (Traefik) so internal traffic
bypasses Cloudflare Tunnel and CF Access authentication.

All other DNS queries are forwarded to upstream resolvers (1.1.1.1, 8.8.8.8).

## Deployment

Managed via `100-pve/main.tf` → `module.lxc_config` pipeline.

## Post-deploy

Update DHCP/router DNS to `192.168.50.103` for internal clients.
