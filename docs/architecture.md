# Architecture Overview

**Last Updated:** 2026-02-14

## System Overview

```
                              Internet
                                 │
                         ┌───────┴───────┐
                         │  Cloudflare   │
                         │  (DNS/Tunnel) │
                         └───────┬───────┘
                                 │
                    ┌────────────┼────────────┐
                    │            │             │
              CF Tunnel    CF Tunnel      CF Workers
            (homelab)    (synology)    (synology-proxy)
                    │            │
                    ▼            ▼
              ┌──────────┐  ┌──────────┐
              │ Traefik  │  │ Synology │
              │   :102   │  │   :215   │
              └────┬─────┘  └──────────┘
                   │
    ┌──────┬──────┬┴─────┬───────┬───────┬──────┐
    ▼      ▼      ▼      ▼       ▼       ▼      ▼
  Grafana  ELK  GlitchTip Supa  Archon  MCPHub  OC
   :104   :105    :106   :107   :108    :112   :200
```

## Network Topology

| Property | Value |
|----------|-------|
| Subnet | `192.168.50.0/24` |
| Gateway | `192.168.50.1` |
| DNS | `192.168.50.1` |
| Domain | `jclee.me` |

## Service Inventory

| VMID | Name | IP | Type | Purpose |
|------|------|----|------|---------|
| 100 | pve | .100 | Host | Proxmox hypervisor |
| 101 | runner | .101 | LXC | GitHub Actions self-hosted runner |
| 102 | traefik | .102 | LXC | Reverse proxy (entry point) |
| 104 | grafana | .104 | LXC | Observability (Prometheus + Grafana) |
| 105 | elk | .105 | LXC | ELK Stack (ES + Logstash + Kibana) |
| 106 | glitchtip | .106 | LXC | Error tracking |
| 107 | supabase | .107 | LXC | Backend-as-a-Service |
| 108 | archon | .108 | LXC | AI knowledge management |
| 112 | mcphub | .112 | VM | MCP Hub + n8n + Vault |
| 200 | oc | .200 | VM | Development (GPU: RTX 5070 Ti) |
| 215 | synology | .215 | Physical | NAS storage |
| 220 | sandbox | .220 | VM | Dev sandbox (CF WARP) |

## External Providers

| ID | Provider | Purpose |
|----|----------|---------|
| 300 | Cloudflare | DNS, tunnels, Access, R2, Workers |
| 301 | GitHub | Repository, branch protection, Actions |

## Data Flows

### Config Pipeline
```
hosts.tf (SSoT) → env-config → config-renderer → tf-configs/
```
All IPs and ports are defined in `100-pve/envs/prod/hosts.tf`. No hardcoded IPs in `main.tf`.

### Deployment Flow
```
Edit config → terraform plan → terraform apply → verify
```

### Observability Flow
```
Services → Filebeat → Logstash:5044 → Elasticsearch:9200 → Grafana:3000
Services → node_exporter → Prometheus:9090 → Grafana:3000
```

### External Access Flow
```
Internet → Cloudflare DNS → CF Tunnel → Traefik:102 → Service LXC/VM
```

## Module Structure

```
modules/
├── proxmox/
│   ├── lxc/              # LXC container provisioning
│   ├── lxc-config/       # LXC config rendering (templates/)
│   ├── vm-config/        # VM config rendering (templates/)
│   ├── env-config/       # Environment config (IP/port mapping)
│   ├── config-renderer/  # Template → tf-configs pipeline
│   └── inventory/        # Host inventory management
├── cloudflare/           # DNS and tunnel modules
└── shared/
    └── vault-secrets/    # HashiCorp Vault secret management
```

## Terraform Workspaces

| Workspace | Provider | Manages |
|-----------|----------|---------|
| `100-pve/` | Proxmox (bpg) | All LXCs (101-108) and VMs (112, 200, 220) |
| `108-archon/terraform/` | Proxmox | Archon standalone |
| `300-cloudflare/` | Cloudflare | DNS, tunnels, R2, Workers, Access |
| `301-github/` | GitHub (integrations) | Repos, branch protection, Actions |

## Build System

Bazel (Google3 style). Every directory has `BUILD.bazel` and `OWNERS`.

```bash
bazel build //...   # Build all targets
bazel test //...    # Test all targets
```
