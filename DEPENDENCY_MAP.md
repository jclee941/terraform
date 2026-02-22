# Terraform Monorepo — Dependency Graph & Entry Points

**Generated:** 2026-02-20
**Scope:** Complete module dependency mapping, template inventory, provider matrix

---

## WORKSPACE ENTRY POINTS

### PRIMARY ORCHESTRATOR

| Workspace   | Entry Point           | Role              | Modules Used                                                         |
| ----------- | --------------------- | ----------------- | -------------------------------------------------------------------- |
| **100-pve** | `main.tf` (844 lines) | Central infra hub | lxc, vm, vm-config, lxc-config, config-renderer, onepassword-secrets |

### SECONDARY WORKSPACES (Terraform-managed)

| Workspace          | Entry Point         | Role                     | Modules Used            | Providers                      |
| ------------------ | ------------------- | ------------------------ | ----------------------- | ------------------------------ |
| **102-traefik**    | `terraform/main.tf` | Reverse proxy config     | None (direct resources) | None (template-only)           |
| **104-grafana**    | `terraform/main.tf` | Observability dashboards | None                    | grafana ~>3.0                  |
| **105-elk**        | `terraform/main.tf` | Log aggregation          | None                    | elasticstack ~>0.10            |
| **108-archon**     | `terraform/main.tf` | AI knowledge mgmt        | None                    | None (LXC-managed)             |
| **300-cloudflare** | `main.tf`           | External DNS/tunnel      | None                    | cloudflare ~>4.0, github ~>6.0 |
| **301-github**     | `main.tf`           | GitHub org/repo mgmt     | None                    | github ~>6.0                   |

### TEMPLATE-ONLY WORKSPACES (No Terraform)

| Workspace         | Purpose               | Templates          | Rendered By                    |
| ----------------- | --------------------- | ------------------ | ------------------------------ |
| **101-runner**    | GitHub Actions runner | filebeat.yml.tftpl | 100-pve/module.config_renderer |
| **106-glitchtip** | Error tracking        | 3x .tftpl          | 100-pve/module.config_renderer |
| **107-supabase**  | Backend-as-a-Service  | 3x .tftpl          | 100-pve/module.config_renderer |
| **112-mcphub**    | MCP server hub        | 4x .tftpl          | 100-pve/module.config_renderer |
| **215-synology**  | NAS inventory         | None (data only)   | Manual                         |
| **220-staging**   | Staging VM            | None (reserved)    | Manual                         |

---

## MODULE DEPENDENCY GRAPH

### CORE MODULES (modules/proxmox/)

```
modules/proxmox/
├── lxc/                    # LXC container provisioning
│   ├── main.tf             # proxmox_virtual_environment_lxc resource
│   ├── variables.tf        # vmid, hostname, ip, cores, memory, disk_size, etc.
│   └── outputs.tf          # container_id, container_status
│
├── vm/                     # QEMU VM provisioning
│   ├── main.tf             # proxmox_virtual_environment_vm resource
│   ├── variables.tf        # vmid, vm_name, cores, memory, disk_size, cloud_init_file
│   └── outputs.tf          # vm_id, vm_status
│
├── lxc-config/             # LXC config rendering
│   ├── main.tf             # Renders lxc-systemd.service.tftpl
│   ├── variables.tf        # hostname, ip, service_name, etc.
│   ├── outputs.tf          # rendered_config
│   └── templates/
│       └── lxc-systemd.service.tftpl
│
├── vm-config/              # VM config rendering (cloud-init)
│   ├── main.tf             # Renders cloud-init.yaml.tftpl + systemd.service.tftpl
│   ├── variables.tf        # hostname, ip, cloud_init_vars, etc.
│   ├── outputs.tf          # rendered_cloud_init, rendered_systemd
│   └── templates/
│       ├── cloud-init.yaml.tftpl
│       └── systemd.service.tftpl
│
└── config-renderer/        # Central template rendering pipeline
    ├── main.tf             # Renders all service .tftpl files
    ├── variables.tf        # hosts, template_vars, service_configs
    └── outputs.tf          # rendered_configs (map of service → rendered content)
```

### SHARED MODULES (modules/shared/)

```
modules/shared/
└── onepassword-secrets/    # 1Password secret fetching
    ├── main.tf             # data "onepassword_item" × 12 services
    ├── variables.tf        # vault_name (default: "homelab")
    └── outputs.tf          # secrets map (grafana, glitchtip, proxmox, etc.)
```

---

## DEPENDENCY FLOW (100-pve → Modules)

```
100-pve/main.tf
├── module "hosts"
│   └── source: ./envs/prod
│       └── hosts.tf (SSoT: IPs, VMIDs, roles)
│
├── module "lxc"
│   └── source: ../modules/proxmox/lxc
│       └── Provisions 7 containers (101-108)
│
├── module "vm"
│   └── source: ../modules/proxmox/vm
│       └── Provisions 1 VM (112-mcphub)
│
├── module "vm_config"
│   └── source: ../modules/proxmox/vm-config
│       └── Renders cloud-init for VM 112
│
├── module "lxc_config"
│   └── source: ../modules/proxmox/lxc-config
│       └── Renders systemd configs for containers
│
├── module "onepassword_secrets"
│   └── source: ../modules/shared/onepassword-secrets
│       └── Fetches 12 service secrets from 1Password
│
└── module "config_renderer"
    └── source: ../modules/proxmox/config-renderer
        └── Renders all service templates:
            ├── 101-runner/templates/filebeat.yml.tftpl
            ├── 102-traefik/templates/*.yml.tftpl (13 routes)
            ├── 104-grafana/templates/*.yml.tftpl
            ├── 105-elk/templates/*.tftpl
            ├── 106-glitchtip/templates/*.tftpl
            ├── 107-supabase/templates/*.tftpl
            ├── 108-archon/templates/*.tftpl
            └── 112-mcphub/templates/*.tftpl
```

---

## TEMPLATE INVENTORY

### By Workspace

| Workspace                      | Template                      | Purpose             | Rendered By       | Output Path                                     |
| ------------------------------ | ----------------------------- | ------------------- | ----------------- | ----------------------------------------------- |
| **101-runner**                 | filebeat.yml.tftpl            | Filebeat config     | config-renderer   | configs/lxc-101-runner/filebeat.yml             |
| **102-traefik**                | archon.yml.tftpl              | Traefik route       | config-renderer   | configs/rendered/traefik/archon.yml             |
|                                | glitchtip.yml.tftpl           | Traefik route       | config-renderer   | configs/rendered/traefik/glitchtip.yml          |
|                                | supabase.yml.tftpl            | Traefik route       | config-renderer   | configs/rendered/traefik/supabase.yml           |
|                                | filebeat.yml.tftpl            | Filebeat config     | config-renderer   | configs/lxc-102-traefik/filebeat.yml            |
|                                | synology.yml.tftpl            | Traefik route       | config-renderer   | configs/rendered/traefik/synology.yml           |
|                                | traefik-elk.yml.tftpl         | Traefik route       | config-renderer   | configs/rendered/traefik/traefik-elk.yml        |
|                                | vault.yml.tftpl               | Traefik route       | config-renderer   | configs/rendered/traefik/vault.yml              |
|                                | mcphub.yml.tftpl              | Traefik route       | config-renderer   | configs/rendered/traefik/mcphub.yml             |
|                                | n8n.yml.tftpl                 | Traefik route       | config-renderer   | configs/rendered/traefik/n8n.yml                |
| **104-grafana**                | filebeat.yml.tftpl            | Filebeat config     | config-renderer   | configs/lxc-104-grafana/filebeat.yml            |
|                                | grafana-datasources.yml.tftpl | Grafana datasources | config-renderer   | configs/lxc-104-grafana/grafana-datasources.yml |
|                                | prometheus.yml.tftpl          | Prometheus config   | config-renderer   | configs/lxc-104-grafana/prometheus.yml          |
| **105-elk**                    | filebeat.yml.tftpl            | Filebeat config     | config-renderer   | configs/lxc-105-elk/filebeat.yml                |
|                                | Dockerfile.logstash.tftpl     | Logstash container  | config-renderer   | configs/lxc-105-elk/Dockerfile.logstash         |
|                                | setup-ilm.sh.tftpl            | ILM setup script    | config-renderer   | configs/lxc-105-elk/setup-ilm.sh                |
|                                | ilm-policy.json.tftpl         | ILM policy          | config-renderer   | configs/lxc-105-elk/ilm-policy.json             |
|                                | docker-compose.yml.tftpl      | ELK stack           | config-renderer   | configs/lxc-105-elk/docker-compose.yml          |
|                                | logstash.conf.tftpl           | Logstash pipeline   | config-renderer   | configs/lxc-105-elk/logstash.conf               |
|                                | logstash.yml.tftpl            | Logstash config     | config-renderer   | configs/lxc-105-elk/logstash.yml                |
| **106-glitchtip**              | glitchtip.env.tftpl           | Env vars            | config-renderer   | configs/lxc-106-glitchtip/glitchtip.env         |
|                                | filebeat.yml.tftpl            | Filebeat config     | config-renderer   | configs/lxc-106-glitchtip/filebeat.yml          |
|                                | docker-compose.yml.tftpl      | GlitchTip stack     | config-renderer   | configs/lxc-106-glitchtip/docker-compose.yml    |
| **107-supabase**               | filebeat.yml.tftpl            | Filebeat config     | config-renderer   | configs/lxc-107-supabase/filebeat.yml           |
|                                | docker-compose.yml.tftpl      | Supabase stack      | config-renderer   | configs/lxc-107-supabase/docker-compose.yml     |
|                                | .env.tftpl                    | Env vars            | config-renderer   | configs/lxc-107-supabase/.env                   |
| **108-archon**                 | filebeat.yml.tftpl            | Filebeat config     | config-renderer   | configs/lxc-108-archon/filebeat.yml             |
|                                | docker-compose.yml.tftpl      | Archon stack        | config-renderer   | configs/lxc-108-archon/docker-compose.yml       |
|                                | .env.tftpl                    | Env vars            | config-renderer   | configs/lxc-108-archon/.env                     |
| **112-mcphub**                 | filebeat.yml.tftpl            | Filebeat config     | config-renderer   | configs/vm-112-mcphub/filebeat.yml              |
|                                | docker-compose.yml.tftpl      | MCPHub stack        | config-renderer   | configs/vm-112-mcphub/docker-compose.yml        |
|                                | mcp_settings.json.tftpl       | MCP server catalog  | config-renderer   | configs/rendered/mcphub/mcp_settings.json       |
|                                | .env.tftpl                    | Env vars            | config-renderer   | configs/vm-112-mcphub/.env                      |
| **modules/proxmox/vm-config**  | cloud-init.yaml.tftpl         | Cloud-init          | vm-config module  | (inline in VM resource)                         |
|                                | systemd.service.tftpl         | Systemd service     | vm-config module  | (inline in VM resource)                         |
| **modules/proxmox/lxc-config** | lxc-systemd.service.tftpl     | Systemd service     | lxc-config module | (inline in LXC resource)                        |

### Template Variables (from 100-pve/main.tf)

```hcl
template_vars = {
  # Host inventory
  hosts = module.hosts.hosts

  # Service secrets (from 1Password)
  grafana_admin_password = module.onepassword_secrets.secrets.grafana.admin_password
  glitchtip_secret_key = module.onepassword_secrets.secrets.glitchtip.secret_key
  # ... 10 more services

  # MCP catalog
  mcp_servers = local.mcp_catalog.servers
  mcp_hub_servers = local.mcp_hub_servers

  # Service-specific vars
  traefik_domain = "jclee.me"
  elk_memory = local.container_sizing.elk.memory
  # ... per-service overrides
}
```

---

## PROVIDER REQUIREMENTS MATRIX

### By Workspace

| Workspace          | Provider              | Version | Auth Method           | Purpose              |
| ------------------ | --------------------- | ------- | --------------------- | -------------------- |
| **100-pve**        | bpg/proxmox           | ~>0.94  | API token (env)       | LXC/VM provisioning  |
|                    | 1Password/onepassword | ~>3.2   | Service account (env) | Secret fetching      |
| **102-traefik**    | None                  | —       | —                     | Template-only        |
| **104-grafana**    | grafana/grafana       | ~>3.0   | API token (env)       | Dashboard/alert mgmt |
| **105-elk**        | elastic/elasticstack  | ~>0.10  | API key (env)         | Index/ILM/space mgmt |
| **108-archon**     | None                  | —       | —                     | LXC-managed          |
| **300-cloudflare** | cloudflare/cloudflare | ~>4.0   | API token (env)       | DNS/tunnel/access    |
|                    | github/github         | ~>6.0   | Token (env)           | Repo/secret mgmt     |
| **301-github**     | github/github         | ~>6.0   | Token (env)           | Org/repo/team mgmt   |

### Environment Variables (Required for CI/Local)

```bash
# Core infrastructure
export PROXMOX_VE_ENDPOINT="https://pve.jclee.me:8006"
export PROXMOX_VE_API_TOKEN="PVEAPIToken=user@pam!terraform=..."
export OP_SERVICE_ACCOUNT_TOKEN="ops_..."

# Secondary workspaces
export GRAFANA_URL="http://192.168.50.104:3000"
export GRAFANA_AUTH="admin:${GRAFANA_ADMIN_PASSWORD}"
export ELASTICSEARCH_ENDPOINTS="http://192.168.50.105:9200"
export ELASTICSEARCH_USERNAME="elastic"
export ELASTICSEARCH_PASSWORD="${ELK_ELASTIC_PASSWORD}"
export CLOUDFLARE_API_TOKEN="..."
export GITHUB_TOKEN="ghp_..."
```

---

## DATA SOURCES USED

| Data Source                                             | Workspace            | Purpose                                        |
| ------------------------------------------------------- | -------------------- | ---------------------------------------------- |
| `data "proxmox_virtual_environment_nodes"`              | 100-pve              | Validate Proxmox node availability             |
| `data "onepassword_vault"`                              | 100-pve (via module) | Resolve vault UUID by name                     |
| `data "onepassword_item"`                               | 100-pve (via module) | Fetch 12 service secrets                       |
| `data "grafana_data_source"`                            | 104-grafana          | Reference Prometheus/Elasticsearch datasources |
| `data "github_repository"`                              | 301-github           | Reference existing repos for team assignment   |
| `data "github_user"`                                    | 301-github           | Resolve GitHub usernames                       |
| `data "cloudflare_zero_trust_tunnel_cloudflared_token"` | 300-cloudflare       | Fetch tunnel token                             |
| `data "terraform_remote_state"`                         | (none currently)     | Cross-workspace state reference (reserved)     |

---

## ENTRY POINT SUMMARY

### For New Contributors

1. **Understanding Infrastructure**: Start at `/home/jclee/dev/terraform/100-pve/main.tf` (844 lines)
2. **Host Inventory**: Read `/home/jclee/dev/terraform/100-pve/envs/prod/hosts.tf` (SSoT)
3. **Module Behavior**: Read `/home/jclee/dev/terraform/modules/proxmox/AGENTS.md`
4. **Service Config**: Check `/home/jclee/dev/terraform/{NNN}-{svc}/templates/` for template logic
5. **Rendered Outputs**: Never edit `/home/jclee/dev/terraform/100-pve/configs/` (auto-generated)

### For Workspace-Specific Work

- **Traefik routes**: Edit `/home/jclee/dev/terraform/102-traefik/templates/*.yml.tftpl`
- **Grafana dashboards**: Edit `/home/jclee/dev/terraform/104-grafana/terraform/main.tf`
- **ELK pipelines**: Edit `/home/jclee/dev/terraform/105-elk/templates/logstash.conf.tftpl`
- **GitHub org**: Edit `/home/jclee/dev/terraform/301-github/main.tf`
- **Cloudflare DNS**: Edit `/home/jclee/dev/terraform/300-cloudflare/main.tf`

### For Module Development

- **LXC provisioning**: `/home/jclee/dev/terraform/modules/proxmox/lxc/main.tf`
- **VM provisioning**: `/home/jclee/dev/terraform/modules/proxmox/vm/main.tf`
- **Config rendering**: `/home/jclee/dev/terraform/modules/proxmox/config-renderer/main.tf`
- **Secret fetching**: `/home/jclee/dev/terraform/modules/shared/onepassword-secrets/main.tf`

---

## CRITICAL RULES

1. **NEVER hand-edit** `/home/jclee/dev/terraform/100-pve/configs/` — regenerate via `terraform apply`
2. **ALWAYS use** `module.hosts.hosts[name].ip` for IPs (never hardcode)
3. **ALWAYS validate** with `terraform plan` before `terraform apply`
4. **ALWAYS source** templates from workspace `templates/` directories
5. **ALWAYS inject secrets** via environment variables (never in `.tf` files)
6. **NEVER commit** `.tfvars`, `.env`, `.tfstate`, or API keys
