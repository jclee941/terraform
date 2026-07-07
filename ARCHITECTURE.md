# Architecture

**Last Updated:** 2026-05-07

## Overview

Homelab infrastructure-as-code monorepo. Provisions a Proxmox LXC/VM fleet, networking, monitoring, and external services via Terraform workspaces with 1Password secret injection and GitHub Actions CI/CD.

- **Domain**: `jclee.me`
- **Subnet**: `192.168.50.0/24`
- **Terraform**: 1.10.5 (`>= 1.7, < 2.0`)

## Tech Stack

| Component | Version | Purpose |
| --------- | ------- | ------- |
| Terraform | 1.10.5 | Infrastructure provisioning |
| bpg/proxmox | ~>0.94 | Proxmox VE provider |
| 1Password/onepassword | ~>3.2 | Secret retrieval |
| elastic/elasticstack | ~>0.13 | ILM/index template management |
| cloudflare/cloudflare | ~>5.0 | DNS, tunnels, Access, Workers |
| TFLint | 0.10.0 | Terraform linting (recommended preset) |
| Pre-commit | — | Hook repos (tf, yaml, secrets, actions) |
| Checkov | — | Security scanning |

## Directory Structure

```
terraform/
├── 80-jclee/                     # Personal workspace (skeleton)
├── 100-pve/                      # Tier 0: Central orchestrator (all LXC/VM lifecycle)
│   ├── terraform/                # Root module (.tf files live here, not at workspace root)
│   │   ├── main.tf               # Providers, module calls
│   │   ├── locals.tf             # Sizing, VM defs, config maps
│   │   ├── checks.tf             # TF 1.5+ validation checks
│   │   ├── firewall.tf           # Proxmox firewall rules (module.firewall_*)
│   │   ├── variables.tf          # Input variables with validation
│   │   └── versions.tf           # required_version, backend, required_providers
│   ├── envs/prod/hosts.tf        # SSoT: all host IPs, VMIDs, roles, ports
│   └── configs/                  # Rendered outputs (never hand-edit)
├── 101-runner/                   # Template-only: GitHub Actions runner
├── 102-traefik/                  # Tier 1: Reverse proxy config
├── 103-coredns/                  # Template-only: Split DNS
├── 105-elk/                      # Tier 1: Log aggregation (ES + Logstash + Kibana)
├── 112-mcphub/                   # Template-only: MCP Hub + 1Password Connect
├── 200-oc/                       # Template-only: OpenCode dev environment
├── 215-synology/                 # Flat Terraform workspace: Synology NAS inventory
├── 220-youtube/                  # Template-only: YouTube automation VM
├── 300-cloudflare/               # Independent: DNS, tunnels, Access, Workers, R2
├── 310-safetywallet/             # Template-only
├── 400-gcp/                      # Independent: Google Cloud Platform
├── modules/
│   ├── cloudflare/
│   │   └── tunnel/               # Reusable Cloudflare tunnel module
│   ├── elasticstack/
│   │   ├── ilm_policy/           # Elasticsearch ILM helper
│   │   └── index_template/       # Elasticsearch index template helper
│   ├── proxmox/
│   │   ├── lxc/                  # LXC container provisioning
│   │   ├── vm/                   # QEMU VM provisioning
│   │   ├── firewall/             # Proxmox firewall resources
│   │   ├── lxc-config/           # LXC config rendering (systemd templates)
│   │   ├── vm-config/            # VM cloud-init + systemd rendering
│   │   └── config-renderer/      # Central template → config pipeline
│   └── shared/
│       └── onepassword-secrets/  # 1Password secret retrieval (12 items, 48 keys)
├── tests/
│   ├── modules/                  # Unit tests (proxmox, shared)
│   ├── integration/              # Cross-module integration tests
│   └── workspaces/               # Workspace validation tests
├── scripts/                      # Operational tooling (Go)
├── docs/                         # Architecture docs, ADRs, runbooks
├── .github/workflows/            # CI/CD workflows
├── AGENTS.md                     # AI agent project context (synced from .github)
├── DEPENDENCY_MAP.md             # Module dependency graph + template inventory
└── Makefile                      # Build/lint/test/verify targets
```

> **Layout convention**: Active workspaces keep their root module under a nested
> `{workspace}/terraform/` directory (e.g. `100-pve/terraform/`, `102-traefik/terraform/`,
> `105-elk/terraform/`, `300-cloudflare/terraform/`). The Makefile aliases resolve to these
> nested paths. The one exception is `215-synology/`, whose `.tf` files live at the workspace
> root. `make` targets (`fmt`, `validate`, `lint`) scan the directories that actually contain
> `.tf` (see `TF_WORKSPACE_DIRS` in the Makefile), so both layouts are covered.

## Workspace Tiers

| Tier | Workspaces | Role | Apply Order |
| ---- | ---------- | ---- | ----------- |
| 0 (core) | `100-pve` | Central orchestrator. Provisions 7 LXC + 3 VM. | First |
| 1 (infra) | `102-traefik`, `105-elk` | Consume `terraform_remote_state` from 100-pve. | Second (parallel) |
| Independent | `300-cloudflare`, `400-gcp` | No Proxmox dependency. | Third (parallel) |
| Template/config-only | `101-runner`, `103-coredns`, `112-mcphub`, `200-oc`, `220-youtube`, `310-safetywallet` | Config templates + docker-compose only, no workspace-local `.tf` files. | N/A |

## Service Inventory

| VMID | Name | IP | Type | Purpose |
| ---- | ---- | -- | ---- | ------- |
| 100 | pve | .100 | Host | Proxmox hypervisor |
| 101 | runner | .101 | LXC | GitHub Actions self-hosted runner |
| 102 | traefik | .102 | LXC | Reverse proxy (ingress) |
| 103 | coredns | .103 | LXC | Split DNS |
| 105 | elk | .105 | LXC | ELK Stack |
| 112 | mcphub | .112 | VM | MCP Hub + 1Password Connect |
| 200 | oc | .200 | VM | OpenCode dev environment (RTX 5070 Ti GPU passthrough) |
| 215 | synology | .215 | Physical | NAS storage |
| 220 | youtube | .220 | VM | YouTube automation |
| 250 | pbs | .250 | VM | Proxmox Backup Server |

## Data Flows

### Service Topology

```text
%% diagram: flowchart TB
  Internet["Internet"] --> CFDNS["Cloudflare DNS"]
  CFDNS --> CFAccess["Cloudflare Access"]
  CFAccess --> CFTunnel["Cloudflare Tunnel"]
  CFTunnel --> Traefik["Traefik\nLXC 102"]

  subgraph Homelab["Homelab 192.168.50.0/24"]
    Traefik --> CoreDNS["CoreDNS\nLXC 103"]
    Traefik --> ELK["ELK\nLXC 105"]
    Traefik --> MCPHub["MCPHub\nVM 112"]
    Traefik --> OC["OpenCode\nVM 200"]
    Traefik --> Synology["Synology\nNAS 215"]
    Traefik --> YouTube["YouTube\nVM 220"]
  end

  PVE["Proxmox Host\n100"] --> Homelab
```

### Terraform Control Flow

```text
%% diagram: flowchart LR
  Hosts["100-pve/envs/prod/hosts.tf\nHost SSoT"] --> HostModule["module.hosts"]
  HostModule --> LXC["modules/proxmox/lxc"]
  HostModule --> VM["modules/proxmox/vm"]
  HostModule --> LXCConfig["modules/proxmox/lxc-config"]
  HostModule --> VMConfig["modules/proxmox/vm-config"]

  OP["modules/shared/onepassword-secrets"] --> Renderer["modules/proxmox/config-renderer"]
  HostModule --> Renderer
  Renderer --> Configs["100-pve/terraform/configs/\nGenerated outputs"]

  LXC --> PVEAPI["Proxmox API"]
  VM --> PVEAPI
  LXCConfig --> SSH["SSH deploy"]
  VMConfig --> SSH
  Configs --> SSH
  SSH --> Targets["/opt/{service}/ on LXC/VM"]
```

### Workspace Apply Order

```text
%% diagram: graph TD
  PVE["100-pve\nTier 0 core"] --> Tier1["Tier 1 parallel"]
  Tier1 --> Traefik["102-traefik"]
  Tier1 --> ELK["105-elk"]

  PVE --> Template["Template-only rendered by 100-pve"]
  Template --> Runner["101-runner"]
  Template --> CoreDNS["103-coredns"]
  Template --> MCPHub["112-mcphub"]
  Template --> OC["200-oc"]
  Template --> Synology["215-synology"]
  Template --> YouTube["220-youtube"]

  Independent["Independent external workspaces"] --> Cloudflare["300-cloudflare"]
  Independent --> GCP["400-gcp"]
```

### Observability Flow

```text
%% diagram: flowchart LR
  Services["LXC / VM Services"] --> Filebeat["Filebeat Agents"]
  PVEHost["Proxmox Host"] --> Filebeat
  Cloudflare["Cloudflare Logpush"] --> Logpush["HTTPS Logpush Ingest"]

  Filebeat --> Logstash["Logstash\n105:5044"]
  Logpush --> Logstash
  Logstash --> Elasticsearch["Elasticsearch\n105:9200"]
  Elasticsearch --> Kibana["Kibana\n105"]
```

## Module Architecture

### `modules/proxmox/`

| Module | Purpose | Key Resource |
| ------ | ------- | ------------ |
| `lxc/` | LXC container provisioning | `proxmox_virtual_environment_lxc` |
| `vm/` | QEMU VM provisioning | `proxmox_virtual_environment_vm` |
| `firewall/` | Proxmox firewall resources | `proxmox_virtual_environment_firewall_*` |
| `lxc-config/` | LXC systemd config rendering | `templatefile()` |
| `vm-config/` | VM cloud-init + systemd rendering | `templatefile()` |
| `config-renderer/` | Central template pipeline | `templatefile()` + `local_file` |

### `modules/cloudflare/`

| Module | Purpose | Key Resource |
| ------ | ------- | ------------ |
| `tunnel/` | Cloudflare tunnel + optional ingress config | `cloudflare_zero_trust_tunnel_cloudflared` |

### `modules/elasticstack/`

| Module | Purpose | Key Resource |
| ------ | ------- | ------------ |
| `ilm_policy/` | Elasticsearch lifecycle policy | `elasticstack_elasticsearch_index_lifecycle` |
| `index_template/` | Elasticsearch index template | `elasticstack_elasticsearch_index_template` |

### `modules/shared/`

| Module | Purpose | Key Resource |
| ------ | ------- | ------------ |
| `onepassword-secrets/` | 1Password secret retrieval | `data.onepassword_item` × 12 services |

## State Management

- **Backend**: `backend "local" {}` — state files stored alongside each workspace.
- **Locking**: No remote locking. CI concurrency groups provide serialization.
- **State files**: Git-ignored (`*.tfstate` excluded via `.gitignore`). State lives locally beside each workspace and is recreated/refreshed via CI.

## Secrets

1Password vault `homelab` (12 items, 48 keys) → `onepassword-secrets` module → `.tftpl` templates → `.env` files on hosts.

- **Connect Server**: LXC 112, port 8090
- **Auth**: `OP_CONNECT_TOKEN` + `OP_CONNECT_HOST` environment variables
- **Access pattern**: `module.secrets.secrets["elk_kibana_system_password"]`
go run scripts/sync-vault-secrets.go → GitHub Actions Secrets

## CI/CD

- **Runner**: Self-hosted on LXC 101
- **PR workflow**: `terraform plan` on PR, `terraform apply` on merge to master
- **Local apply**: Disabled (`make apply` exits with error)
- **Drift detection**: Mon–Fri 00:00 UTC via scheduled workflow
- **Actions**: All SHA-pinned with `# vN` version comment
- **Workflows**: `.github/workflows/`, reusable `_*.yml` from `qws941/.github`

## Testing

| Suite | Location | Command |
| ----- | -------- | ------- |
| Unit (modules) | `tests/modules/{proxmox,shared}/` | `make test-unit` |
| Integration | `tests/integration/` | `make test-integration` |
| Workspace validation | `tests/workspaces/{pve,cloudflare,elk}/` | `make test-workspace` |
| All | — | `make test` |

## Key References

| Document | Location |
| -------- | -------- |
| Dependency graph | `DEPENDENCY_MAP.md` |
| Secret lifecycle | `docs/secret-management.md` |
| Workspace ordering | `docs/workspace-ordering.md` |
| Backup strategy | `docs/backup-strategy.md` |
| ADRs | `docs/adr/` |
| Drift detection | Scheduled GitHub Actions workflow (Mon–Fri 00:00 UTC) |
| Alert reference | `docs/ALERTING-REFERENCE.md` |
