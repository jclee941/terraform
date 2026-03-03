# AGENTS: 215-synology

> **IP**: 192.168.50.215 | **Status**: active TF workspace

**Updated:** 2026-03-03
**Target:** Synology NAS (Physical Device)
**IP:** 192.168.50.215
**Provider:** synology-community/synology ~>0.6

## OVERVIEW

Synology NAS providing network-attached storage for the homelab. Managed via the `synology-community/synology` Terraform provider for DSM packages, Docker Compose projects, and file operations. Exposed via Traefik reverse proxy at `nas.jclee.me` (DSM port 5000). Also hosts Cloudflare tunnel connector (`cloudflared`) for external access. Sends syslog events to ELK stack.

## STRUCTURE

```
215-synology/
├── BUILD.bazel       # Monorepo integration
├── OWNERS            # Access control (Infrastructure)
├── AGENTS.md         # This file
├── README.md         # Device documentation
├── syslog-config.md  # Syslog forwarding setup to ELK (105)
├── versions.tf       # Provider + backend config
├── variables.tf      # Input variables (DSM host, credentials)
├── terraform.tfvars  # Non-secret variable values
├── onepassword.tf    # 1Password secret integration
├── main.tf           # Provider config + resources
└── outputs.tf        # Exported values
```

## WHERE TO LOOK

| Task                   | Location                                   | Notes                                    |
| ---------------------- | ------------------------------------------ | ---------------------------------------- |
| **Host definition**    | `100-pve/envs/prod/hosts.tf`               | `synology` entry (IP, ports, roles)      |
| **Provider config**    | `main.tf`                                  | Synology + 1Password providers           |
| **Credentials**        | `onepassword.tf`                           | 1Password priority, variable fallback    |
| **DSM packages**       | `main.tf`                                  | `synology_core_package` resources        |
| **Container projects** | `main.tf`                                  | `synology_container_project` resources   |
| **Traefik routing**    | `102-traefik/templates/synology.yml.tftpl` | `nas.jclee.me` → DSM                     |
| **Cloudflare tunnel**  | `300-cloudflare/`                          | `cloudflared` connector on NAS           |
| **Syslog to ELK**      | `syslog-config.md`                         | DSM syslog forwarding to Logstash on 105 |

## CONVENTIONS

- **Physical Device**: NOT a Proxmox VM/LXC. Managed as an inventory host in `hosts.tf` and via Synology provider.
- **Governance**: Referenced in Terraform via `module.hosts` for IP/port injection into dependent services (Traefik, Cloudflare).
- **Credentials**: DSM admin credentials stored in 1Password vault "homelab" under item "synology".
- **DSM Access**: Port 5001 (HTTPS) for provider API. Port 5000 (HTTP) proxied through Traefik with TLS.
- **Naming**: Follows `{NNN}-{HOSTNAME}` convention where 215 = `192.168.50.215`.
- **Syslog**: DSM configured to forward syslog to Logstash syslog input on LXC 105.

## ANTI-PATTERNS

- **NO hardcoded IPs** in service configs. Use `module.hosts.synology_ip`.
- **NO direct external exposure**. All access must route through Traefik or Cloudflare tunnel.
- **NO plaintext credentials**. Use 1Password integration via `onepassword.tf`.
