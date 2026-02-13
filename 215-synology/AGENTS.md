# PROJECT KNOWLEDGE BASE: 215-SYNOLOGY

**Updated:** 2026-02-13
**Target:** Synology NAS (Physical Device)
**IP:** 192.168.50.215

## OVERVIEW
Synology NAS providing network-attached storage for the homelab. Serves as the primary storage backend for backups, media, and shared data. Exposed via Traefik reverse proxy at `nas.jclee.me` (DSM port 5000). Also hosts Cloudflare tunnel connector (`cloudflared`) for external access.

## STRUCTURE
```
215-synology/
├── BUILD.bazel     # Monorepo integration
├── OWNERS          # Access control (Infrastructure)
├── AGENTS.md       # This file
└── README.md       # Device documentation
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| **Host definition** | `100-pve/envs/prod/hosts.tf` | `synology` entry (IP, ports, roles) |
| **Traefik routing** | `102-traefik/templates/synology.yml.tftpl` | `nas.jclee.me` → DSM |
| **Env config** | `modules/proxmox/env-config/main.tf` | `synology_ip`, `synology_ports` |
| **Main orchestration** | `100-pve/main.tf` | Traefik-synology config rendering |
| **Cloudflare tunnel** | `300-cloudflare/` | `cloudflared` connector on NAS |

## CONVENTIONS
- **Physical Device**: NOT a Proxmox VM/LXC. Managed as an inventory host only.
- **Governance**: Referenced in Terraform via `module.hosts` for IP/port injection into dependent services (Traefik, Cloudflare).
- **DSM Access**: Port 5000 (HTTP). Proxied through Traefik with TLS.
- **Naming**: Follows `{NNN}-{HOSTNAME}` convention where 215 = `192.168.50.215`.

## ANTI-PATTERNS
- **NO Terraform provisioning**. Synology DSM is managed via its own web UI.
- **NO hardcoded IPs** in service configs. Use `module.hosts.synology_ip`.
- **NO direct external exposure**. All access must route through Traefik or Cloudflare tunnel.
