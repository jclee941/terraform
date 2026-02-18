# Architecture Overview

**Last Updated:** 2026-02-16

## System Overview

```
                              Internet
                                 │
                         ┌───────┴───────┐
                         │  Cloudflare   │
                         │  (DNS/Tunnel) │
                         │   (300)       │
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

| VMID | Name | IP | Type | Purpose | Workspace Owner |
|------|------|----|------|---------|-----------------|
| 100 | pve | .100 | Host | Proxmox hypervisor | Manual |
| 101 | runner | .101 | LXC | GitHub Actions self-hosted runner | 100-pve |
| 102 | traefik | .102 | LXC | Reverse proxy (entry point) | 100-pve (lifecycle) + 102-traefik (app config) |
| 104 | grafana | .104 | LXC | Observability (Prometheus + Grafana) | 100-pve (lifecycle) + 104-grafana (dashboards/alerts) |
| 105 | elk | .105 | LXC | ELK Stack (ES + Logstash + Kibana) | 100-pve (lifecycle) + 105-elk (ILM/templates) |
| 106 | glitchtip | .106 | LXC | Error tracking | 100-pve |
| 107 | supabase | .107 | LXC | Backend-as-a-Service | 100-pve |
| 108 | archon | .108 | LXC | AI knowledge management | 100-pve (lifecycle) + 108-archon (app config) |
| 112 | mcphub | .112 | VM | MCP Hub + n8n + Vault | 100-pve |
| 200 | oc | .200 | VM | Development (GPU: RTX 5070 Ti) | 100-pve |
| 215 | synology | .215 | Physical | NAS storage | Inventory only |
| 220 | sandbox | .220 | VM | Dev sandbox (CF WARP, disabled) | 100-pve |

## External Providers

| ID | Provider | Workspace | Purpose |
|----|----------|-----------|---------|
| 300 | Cloudflare | `300-cloudflare/` | DNS, tunnels, Access, R2, Workers, secrets |
| 301 | GitHub | `301-github/` | Repos, teams, rulesets, Actions, webhooks |

## Data Flows

### Config Pipeline
```
100-pve/envs/prod/hosts.tf (SSoT)
         │
         ▼
    module.hosts (local variables)
         │
    ┌────┴────────────────┐
    ▼                     ▼
module.op_secrets       module.config_renderer
    │                     │
    │              renders .tftpl templates
    │                     │
    ▼                     ▼
module.lxc / module.vm   tf-configs/ (per service)
    │                     │
    ▼                     ▼
Proxmox API          cloud-init → /opt/{service}/
```

### Workspace Dependency Graph
```
100-pve (central orchestrator)
    │
    ├── outputs: host_inventory
    │
    ▼  terraform_remote_state consumers:
    ├── 102-traefik/terraform/   (app config only)
    ├── 104-grafana/terraform/   (grafana provider: dashboards, alerts)
    ├── 105-elk/terraform/       (elasticstack provider: ILM, templates)
    ├── 108-archon/terraform/    (app config only)
    └── 301-github/              (github provider: repos, teams)

300-cloudflare (independent — reads 1Password directly)
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
│   ├── vm/               # QEMU VM provisioning
│   ├── lxc-config/       # LXC config rendering (templates/)
│   ├── vm-config/        # VM config rendering (Cloud-init)
│   └── config-renderer/  # Template → tf-configs pipeline
├── cloudflare/           # DNS and tunnel modules (unused by 300-cloudflare)
└── shared/
    └── onepassword-secrets/  # 1Password secret retrieval (service account)
```

## Terraform Workspaces

| Workspace | State Key | Provider(s) | Manages |
|-----------|-----------|-------------|---------|
| `100-pve/` | `100-pve/terraform.tfstate` | bpg/proxmox, 1Password/onepassword | All LXC lifecycle (101-108), VMs (112, 200, 220), config rendering |
| `102-traefik/terraform/` | `102-traefik/terraform.tfstate` | (none) | App-level config deployment via lxc-config |
| `104-grafana/terraform/` | `104-grafana/terraform.tfstate` | grafana/grafana | Dashboards, datasources, alerts, contact points |
| `105-elk/terraform/` | `105-elk/terraform.tfstate` | elastic/elasticstack | ILM policies, index templates |
| `108-archon/terraform/` | `108-archon/terraform.tfstate` | (none) | App-level config deployment via lxc-config |
| `300-cloudflare/` | `300-cloudflare/terraform.tfstate` | cloudflare, github, 1Password/onepassword | DNS zones, tunnels, Access policies, R2, Workers |
| `301-github/` | `301-github/terraform.tfstate` | integrations/github | Repos, teams, rulesets, Actions config, webhooks |

## State Backend

All workspaces use Cloudflare R2 as S3-compatible backend:
- Bucket: `jclee-tf-state`
- Config: `backend.hcl` (shared)
- Init: `terraform init -backend-config=../backend.hcl`

## Build System

Bazel (Google3 style). Every directory has `BUILD.bazel` and `OWNERS`.

```bash
bazel build //...   # Build all targets
bazel test //...    # Test all targets
make plan SVC=100-pve   # Plan specific workspace
```
