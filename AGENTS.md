# PROJECT KNOWLEDGE BASE

**Generated:** 2026-02-13
**Branch:** master
**Style:** Google3 Monorepo (Bazel)

## OVERVIEW
Multi-Provider Infrastructure Management Monorepo. Unified entry point for managing Proxmox homelab and other infrastructure providers (Cloudflare, AWS, etc.) using Terraform and Bazel. Orchestrates LXC containers and VMs for `jclee.me` with strict Google3-style governance (BUILD files, OWNERS). Migrated from single-provider `proxmox/` repo.

## STRUCTURE
```
terraform/                      # Multi-provider IaC monorepo root
├── modules/                    # Reusable Terraform modules
│   ├── proxmox/                # Proxmox-specific modules
│   │   ├── lxc/                # LXC container provisioning
│   │   ├── vm/                 # QEMU VM provisioning
│   │   ├── lxc-config/         # LXC config rendering (templates/)
│   │   ├── vm-config/          # VM config rendering (templates/)
│   │   └── config-renderer/    # Template → tf-configs pipeline
│   └── shared/
│       ├── vault-secrets/      # HashiCorp Vault secret management
│       └── vault-agent/        # Vault Agent AppRole auto-auth module
├── 100-pve/                    # Proxmox Host + TF workspace (primary)
│   ├── main.tf                 # Central orchestration (665 lines)
│   ├── variables.tf            # TF variables
│   ├── terraform.tfvars        # Variable values
│   └── envs/prod/              # Production environment
│       └── hosts.tf            # SSoT: ALL host IPs/ports
├── 101-runner/                 # GitHub Actions Self-hosted Runner (LXC)
├── 102-traefik/                # Reverse Proxy (Entry point)
│   ├── terraform/              # Standalone TF workspace (reserved for Traefik provider)
│   └── templates/              # Config templates
├── 104-grafana/                # Observability Stack (Prometheus/Grafana)
│   └── terraform/              # Standalone TF workspace (grafana provider)
├── 105-elk/                    # ELK Stack (Elasticsearch, Logstash, Kibana)
│   └── terraform/              # Standalone TF workspace (elasticstack provider)
├── 106-glitchtip/              # Error Tracking (GlitchTip)
├── 107-supabase/               # Supabase BaaS (Backend-as-a-Service)
├── 108-archon/                 # AI Knowledge Management (Archon)
│   └── terraform/              # Standalone TF workspace
├── 112-mcphub/                 # MCP Hub (Unified MCP + AI/Tools VM)
│   └── templates/              # docker-compose, mcp_settings.json
├── 200-oc/                     # Dev Environment (GPU VM)
│   ├── cloud-init/             # Cloud-init user-data
│   ├── config/                 # System-level configs (filebeat, systemd)
│   ├── opencode/               # Config gen pipeline (3 variants, 9 agents)
│   │   └── gen/                # Python generators (config.py = SoT)
│   └── scripts/                # VM maintenance scripts
├── 215-synology/               # Synology NAS (Physical Device)
├── 220-staging/                # Staging Environment (Docker)
│   └── cloud-init/             # Cloud-init config
├── 301-github/                 # GitHub Org Management (External)
├── 300-cloudflare/             # Cloudflare Infrastructure (External)
│   ├── *.tf                    # DNS, tunnel, access, R2, secrets (14 files)
│   ├── workers/synology-proxy/ # Hono Worker (FileStation proxy + R2 cache)
│   ├── scripts/                # collect, audit, sync, generate-bindings
│   ├── inventory/secrets.yaml  # Secret metadata SSoT (NO values)
│   └── docker/cloudflared/     # Tunnel connector on Synology NAS
├── tests/                      # Integration + module tests
│   ├── integration/            # Cross-module integration tests
│   └── modules/proxmox/        # Proxmox module unit tests
├── data/                       # Local data (gitignored)
├── docs/                       # Documentation
├── scripts/                    # Utility scripts + n8n-workflows/
├── .github/workflows/          # CI/CD (21 workflows)
└── .archive/                   # Archived services (103, 109-111, 113)
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| **IaC Definitions** | `100-pve/main.tf` | Manages 101-102, 104-108, 112, 200, 220. |
| **Terraform Modules** | `modules/proxmox/` | 5 modules (lxc, vm, lxc-config, vm-config, config-renderer). |
| **Shared Modules** | `modules/shared/vault-secrets/` | Cross-stack modules (Vault secrets). |
| **Vault Agent Module** | `modules/shared/vault-agent/` | AppRole auto-auth + template engine for runtime secrets. |
| **Grafana App Config** | `104-grafana/terraform/` | Standalone workspace: dashboards, datasources, alerts (grafana provider). |
| **ELK App Config** | `105-elk/terraform/` | Standalone workspace: ILM policies, index templates (elasticstack provider). |
| **GitHub Org Mgmt** | `301-github/` | GitHub org, repos, teams, branch protection (github provider). |
| **Cloudflare Infra** | `300-cloudflare/` | DNS, tunnel, access, R2, secrets, Workers (inline resources, no shared module). |
| **Host Inventory (SoT)** | `100-pve/envs/prod/hosts.tf` | Single Source of Truth for all IPs/ports. |
| **Terraform Architecture** | `100-pve/main.tf` → `module.hosts` → `module.env_config` → downstream modules | No hardcoded IPs in main.tf. |
| **Config Templates** | Distributed per service dir | `102-traefik/templates/`, `104-grafana/templates/`, `105-elk/templates/`, `106-glitchtip/templates/`, `112-mcphub/templates/` |
| **Module Templates** | `modules/proxmox/{lxc-config,vm-config}/templates/` | 3 module-level templates. |
| **TF-Rendered Configs** | `100-pve/configs/lxc-{VMID}-{name}/` | Terraform-rendered outputs via config-renderer module. NOT hand-editable. |
| **Self-hosted Runner** | `101-runner/` | GitHub Actions runner (LXC 101). Multi-repo registration scripts. |
| **AI Agents** | `112-mcphub/` | MCP servers + AI tools (unified). |
| **Observability** | `104-grafana/` | Prometheus/Elasticsearch/Grafana stack. |
| **Error Tracking** | `106-glitchtip/` | GlitchTip error tracking (glitchtip.jclee.me). |
| **Supabase BaaS** | `107-supabase/` | Backend-as-a-Service (supabase.jclee.me). |
| **AI Knowledge Mgmt** | `108-archon/` | Archon AI with MCP server (archon.jclee.me). Standalone TF workspace. |
| **MCP Hub** | `112-mcphub/` | MCPHub unified MCP management UI (mcphub.jclee.me). SSoT: `mcp_servers.json` (24 servers). |
| **OpenCode Gen** | `200-oc/opencode/gen/` | Config gen pipeline: 3 variants (anti/claude/copilot), 9 agents, 8 categories. |
| **Routing** | `102-traefik/config/` | Dynamic routing (elk.yml, glitchtip.yml, mcp.yml, vault.yml, mcphub.yml). |
| **Alerting** | `104-grafana/alerting.yaml` | 8 alert rules, 2 contact points (email, n8n-webhook). Slack removed. |
| **CI/CD** | `.github/workflows/` | 21 workflows: terraform-{plan,apply}, terraform-drift, per-service {plan,apply}, internal-service-access, milestone-automation, pr-review, secret-audit, vault-test, worker-deploy. |
| **Scripts** | `scripts/` | create-pr.sh, production_verification_v2.sh, terraform-drift-check.sh. |
| **n8n Workflows** | `scripts/n8n-workflows/` + `112-mcphub/n8n-workflows/` | 8 workflow JSON definitions (6 primary + 2 pipeline). |
| **Runbooks** | `docs/runbooks/` | Incident response and operational guides. |
| **Synology NAS** | `215-synology/` | Physical device inventory. IP/port ref only (no TF provisioning). |
| **Cloudflare Infra** | `300-cloudflare/` | DNS, tunnel, access, R2, secrets, Workers. External provider (300+). |
| **Add New Provider** | `{NNN}-{svc}/` + `modules/{provider}/` | Create flat NNN dir + modules. 300+ for external infra. |

## INFRASTRUCTURE STATUS
| VMID | Name | IP | Purpose | Governance |
|------|------|----|---------|------------|
| 100 | pve | 192.168.50.100 | Proxmox Host | Host configs |
| 101 | runner | 192.168.50.101 | GitHub Actions Runner | Terraform (LXC) |
| 102 | traefik | 192.168.50.102 | Reverse Proxy | Terraform (LXC) |
| 104 | grafana | 192.168.50.104 | Observability | Terraform (LXC) |
| 105 | elk | 192.168.50.105 | ELK Stack | Terraform (LXC) |
| 106 | glitchtip | 192.168.50.106 | Error Tracking (GlitchTip) | Terraform (LXC) ✅ Running |
| 107 | supabase | 192.168.50.107 | Supabase BaaS | Terraform (LXC) |
| 108 | archon | 192.168.50.108 | AI Knowledge Mgmt (Archon) | Terraform (LXC) |
| 112 | mcphub | 192.168.50.112 | MCP Hub (Unified MCP + AI/Tools) | Terraform (VM) ✅ Running |
| 200 | oc | 192.168.50.200 | Dev (GPU) | Terraform (VM) |
| 215 | synology | 192.168.50.215 | Synology NAS (Physical) | Inventory only |
| 220 | staging | 192.168.50.220 | Staging Environment (Docker) | Terraform (VM) |
| 300 | cloudflare | — | DNS/Tunnel/Access/R2/Secrets | Terraform (External) |
| 301 | github | — | GitHub Org/Repos/Teams | Terraform (External) |

## MCP SERVERS
**SSoT: `112-mcphub/mcp_servers.json`** — Centralized catalog for all MCP servers. 24 servers total.

| Server | Location | Port | Notes |
|--------|----------|------|-------|
| sqlite | hub | :8054 | `mcp-server-sqlite` |
| proxmox | hub | :8055 | SSE sidecar (Dockerfile.proxmox) |
| playwright | hub | :8056 | SSE sidecar (Dockerfile.playwright) |
| sequential-thinking | hub | :8057 | `@modelcontextprotocol/server-sequential-thinking` |
| github | hub | :8058 | `@modelcontextprotocol/server-github` |
| git | hub | :8059 | `@cyanheads/git-mcp-server` |
| kratos | hub | :8060 | `kratos-mcp` |
| time | hub | :8062 | `mcp-server-time` (uvx) |
| elk | hub | :8065 | `@awesome-ai/elasticsearch-mcp` |
| websearch | hub | :8067 | `exa-mcp-server` |
| context7 | hub | :8068 | `@upstash/context7-mcp` |
| grafana | hub | :8069 | `@leval/mcp-grafana` |
| terraform | hub | :8071 | `terraform-mcp-server` |
| slack | hub | :8072 | `slack-mcp-server` |
| cf-dns | hub | :8073 | `cloudflare-dns-mcp` |
| splunk | hub | :8074 | `splunk-mcp` |
| glitchtip | hub | :8075 | `mcp-glitchtip` |
| n8n | hub | :5678 | HTTP transport, Bearer auth (env: N8N_MCP_API_KEY) |
| in-memoria | hub | :8076 | `in-memoria` (persistent memory) |
| bazel | hub | :8077 | `github:nacgarg/bazel-mcp-server` |
| cf-docs | hub (external SSE) | — | `docs.mcp.cloudflare.com` |
| cf-observability | hub (external SSE) | — | `observability.mcp.cloudflare.com` |
| cf-radar | hub (external SSE) | — | `radar.mcp.cloudflare.com` |
| cf-workers | hub (external SSE) | — | `bindings.mcp.cloudflare.com` |

**Consumers**: Terraform (`mcp_settings.json.tftpl`), OpenCode gen (`config.py`), validation (`validate_mcps.py`).

## CONVENTIONS
- **Build System**: Bazel (Google3 style). Every dir MUST have `BUILD.bazel` and `OWNERS`.
- **Monorepo Layout**: Flat `{NNN}-{svc}/` directories for Terraform workspaces, `modules/{provider}/` for reusable modules, `modules/shared/` for cross-provider modules. NO `stacks/` subdirectories.
- **Architecture**: `main.tf` → `module.hosts` → `module.env_config` → downstream modules. No hardcoded IPs in `main.tf`.
- **Numbering**: `1-255` = internal infra (maps to `192.168.50.{NNN}`), `300+` = external infra (Cloudflare, AWS, etc.).
- **Naming**: `{VMID}-{HOSTNAME}` (e.g., `102-traefik`).
- **Network**: `192.168.50.0/24` (GW: .1). Primary DNS: `.1`.
- **Terraform**: `bpg/proxmox` (~>0.94), `hashicorp/vault` (~>5.0), `grafana/grafana` (~>4.0), `elastic/elasticstack` (~>0.13), `cloudflare/cloudflare` (~>5.0), `integrations/github` (~>6.6).
- **Single Source of Truth (SSoT)**: `100-pve/envs/prod/hosts.tf` defines ALL IPs/ports. No hardcoded IPs in `main.tf`.
- **Module Sources**: Always use `../modules/{provider}/{module}` relative paths from service dirs.
- **Template Paths**: `${path.module}/../{NNN}-{svc}/templates/` from workspace to service templates.
- **Config Pipeline**: `hosts.tf` → `module.hosts` → `config-renderer` → `100-pve/configs/lxc-{VMID}-{name}/`.
- **Multi-stack Makefile**: `make plan SVC=pve` (default: `100-pve`). Aliases: pve, runner, traefik, grafana, elk, glitchtip, supabase, archon, mcphub, oc, synology, staging, cloudflare, github.
- **Cloud-Init**: Custom snippets via `proxmox_virtual_environment_file`.
- **Logs**: Filebeat → Logstash:5044 → Elasticsearch (105) → Grafana.
- **PR Automation**: Use the dedicated `pr-automation` skill for all Pull Request operations.
- **Memory Budget**: Total allocation < 90% physical RAM. Current limit: 54 GB.

## COMMANDS
```bash
ssh pve; pct enter {VMID}  # LXC access via PVE
ssh root@192.168.50.100 'pct exec {VMID} -- bash -c "CMD"'
bazel build //... && bazel test //...
make plan                        # Default: SVC=100-pve
make plan SVC=pve                # Explicit service (alias)
make apply SVC=pve               # Apply proxmox stack
cd 100-pve && terraform plan -out=tfplan && terraform apply tfplan
```

## ANTI-PATTERNS
- **Infrastructure (IaC)**:
  - **NO UI tweaks** on Terraform-managed LXCs (102-106). Causes drift.
  - **NO manual state edits**. Use `terraform` CLI or OpenTofu.
  - **NO hardcoded IPs** in `main.tf`. Use `module.hosts`.
  - **NO hardcoded module paths**. Use `../modules/{provider}/{module}` relative paths.
  - **NO hand-editing** of TF-rendered configs in `100-pve/configs/`.
- **Security**:
  - **NEVER commit .env files**. Use Vault Agent or `.env.example` templates.
  - **NEVER commit API keys**: Protect `antigravity-accounts.json` and signature caches.
  - **NEVER put tokens** in Splunk `default/*.conf` files.
- **Development**:
  - **NEVER use `as any`**, `@ts-ignore`, or `@ts-expect-error`.
  - **NEVER empty catch blocks**. Always log errors.
  - **NEVER use `print()`** in Splunk python scripts; use Splunk logging.
  - **NO global npm/pip** on MCP. Use Bazel or absolute paths.
  - **NO runtime pip install** inside Docker containers.
- **Service-Specific**:
  - **NO mcp-server-elasticsearch** (RajwardhanShinde); incompatible with xpack disabled.
  - **NO direct SSH** to LXCs (102-106); use `pct exec` via PVE.

## AUTOMATION PIPELINES (n8n)
8 workflows on n8n (VM 112, :5678). Login: see Vault `homelab/n8n`.
- **Primary** (6): `scripts/n8n-workflows/` — error→issue, alert→issue, daily-digest, request-tracker, PR-notify, error-handler.
- **Pipeline** (2): `112-mcphub/n8n-workflows/` — ELK error pipeline, GlitchTip sync.
- **Webhooks**: `/webhook/glitchtip-error`, `/webhook/grafana-alert`, `/webhook/github-issue`, `/webhook/github-pr`.

## NOTES
- **n8n**: MCP API key expires 2026-05-11. Workflows must be Published via UI (CLI import doesn't register webhooks).
- **GlitchTip**: Org `jclee-homelab`, Project `homelab`. Alert rule `n8n-automation` → webhook.
- **Vault**: vault.jclee.me via Traefik. Vault Agent module at `modules/shared/vault-agent/` (AppRole auto-auth, pilot target: VM 112). Plan-time secrets via `modules/shared/vault-secrets/`. Deprecated vars: `n8n_mcp_config`, `mcp_secrets`.
- **MCPHub**: Default creds — see Vault `homelab/mcphub`. SSE proxies use sidecar Dockerfiles (`Dockerfile.proxmox`, `Dockerfile.playwright`). Env from `/opt/mcphub/.env`.
- **GPU**: RTX 5070 Ti on VM 200 (IOMMU group 12, PCI 0000:01:00.0). **Archived**: 109-111, 113 → `.archive/`.
- **Migration**: Migrated from single-provider `~/dev/proxmox/` repo (2026-02-13). Original repo preserved as reference.
- **Cloudflare**: Migrated from standalone `~/dev/cloudflare/` repo (2026-02-13). Includes Workers, scripts, docker, inventory.
