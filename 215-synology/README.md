# 215-synology

Synology NAS — network-attached storage for the homelab.

- **IP**: `192.168.50.215`
- **DSM**: Port 5000 (proxied via Traefik at `nas.jclee.me`)
- **Roles**: NAS, Storage

## Integration

This device is referenced as a host in `100-pve/envs/prod/hosts.tf` and consumed by:
- **Traefik** (`102-traefik/templates/synology.yml.tftpl`) for reverse proxy routing
- **Cloudflare** (`300-cloudflare/`) for tunnel connectivity

## Notes

- Physical device, not managed by Terraform provisioning
- Configuration changes are made via Synology DSM web UI
- IP and port information flows through `module.hosts` → `module.env_config`
