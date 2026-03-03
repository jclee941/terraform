# 215-synology

Synology NAS — network-attached storage for the homelab, managed via Terraform.

- **IP**: `192.168.50.215`
- **DSM**: Port 5001 (HTTPS API), Port 5000 (HTTP proxied via Traefik at `nas.jclee.me`)
- **Roles**: NAS, Storage
- **Provider**: `synology-community/synology` ~>0.6

## Terraform Resources

| Resource | Purpose |
|----------|---------|
| `synology_core_package.container_manager` | Ensure ContainerManager package is installed |
| `data.synology_core_network.this` | Read NAS network configuration |

## Integration

This device is referenced as a host in `100-pve/envs/prod/hosts.tf` and consumed by:
- **Traefik** (`102-traefik/templates/synology.yml.tftpl`) for reverse proxy routing
- **Cloudflare** (`300-cloudflare/`) for tunnel connectivity
- **ELK** (`105-elk/`) for syslog ingestion

## Credentials

DSM admin credentials are stored in 1Password vault "homelab" under item "synology" with fields:
- `secrets.user` — DSM admin username
- `secrets.password` — DSM admin password

## Usage

```bash
make plan SVC=synology    # Plan changes
# Apply via CI only (merge to master)
```

## Notes

- Physical device, not a Proxmox VM/LXC
- Provider requires DSM 7.0+ with HTTPS enabled on port 5001
- `skip_cert_check = true` for self-signed DSM certificates
- IP and port information flows through `module.hosts` → dependent workspaces
