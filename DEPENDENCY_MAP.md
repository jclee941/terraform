# Terraform Monorepo — Dependency Graph & Entry Points

**Generated:** 2026-07-23
**Scope:** Complete module dependency mapping, template inventory, provider matrix

---

## WORKSPACE ENTRY POINTS

### PRIMARY ORCHESTRATOR

| Workspace   | Entry Point           | Role              | Modules Used                                                         |
| ----------- | --------------------- | ----------------- | -------------------------------------------------------------------- |
| **100-pve** | `main.tf` (77 lines) | Central infra hub | lxc, vm, vm-config, lxc-config, config-renderer, onepassword-secrets |

### SECONDARY WORKSPACES (Terraform-managed)

| Workspace          | Entry Point         | Role                     | Modules Used            | Providers                                           |
| ------------------ | ------------------- | ------------------------ | ----------------------- | --------------------------------------------------- |
| **105-elk**        | `terraform/main.tf` | Log aggregation          | None                    | elasticstack ~>0.13, onepassword ~>3.2              |
| **215-synology**   | `main.tf`           | NAS management           | onepassword-secrets     | synology ~>0.6, onepassword ~>3.2                   |
| **300-cloudflare** | `main.tf`           | External DNS/tunnel      | onepassword-secrets     | cloudflare ~>5.0, random ~>3.0, onepassword ~>3.2, time ~>0.12 |

### TEMPLATE-ONLY WORKSPACES (No Terraform)

| Workspace         | Purpose               | Templates          | Rendered By                    |
| ----------------- | --------------------- | ------------------ | ------------------------------ |
| **200-oc**        | OpenCode VM          | —                 | 100-pve/module.config_renderer |
| **220-youtube**   | YouTube VM           | 3x .tftpl         | 100-pve/module.config_renderer |

### PLACEHOLDER WORKSPACES

| Workspace           | Status    | Notes                        |
| ------------------- | --------- | ---------------------------- |
| **80-jclee**        | Reserved  | Workstation documentation    |
| **200-oc**          | Reserved  | OpenCode workspace docs      |
| **310-safetywallet**| Reserved  | Placeholder                  |
| **400-gcp**         | Reserved  | Placeholder                  |

---

## MODULE DEPENDENCY GRAPH

```text
%% diagram: graph TD
  Main["100-pve/terraform/main.tf"] --> Hosts["100-pve/envs/prod/hosts.tf"]
  Main --> LXC["modules/proxmox/lxc"]
  Main --> VM["modules/proxmox/vm"]
  Main --> LXCConfig["modules/proxmox/lxc-config"]
  Main --> VMConfig["modules/proxmox/vm-config"]
  Main --> Renderer["modules/proxmox/config-renderer"]
  Main --> Secrets["modules/shared/onepassword-secrets"]

  Hosts --> Renderer
  Secrets --> Renderer
  Renderer --> Rendered["100-pve/terraform/configs/"]
  LXC --> Proxmox["Proxmox LXC Resources"]
  VM --> ProxmoxVM["Proxmox VM Resources"]
  LXCConfig --> LXCGuest["LXC Guest Config"]
  VMConfig --> VMGuest["VM Cloud-Init / Systemd"]
  Cloudflare["300-cloudflare"] --> Tunnel["cloudflared-homelab on cliproxy (114)"]
  Tunnel --> Origins["Direct service IP:port origins"]
```

### CORE MODULES (modules/proxmox/)

| Module            | Purpose                        | Key Outputs                     |
| ----------------- | ------------------------------ | ------------------------------- |
| `lxc`             | LXC container provisioning     | container_id, container_status  |
| `vm`              | QEMU VM provisioning           | vm_id, vm_status                |
| `lxc-config`      | LXC config rendering           | rendered_config                 |
| `vm-config`       | VM cloud-init / systemd        | rendered_cloud_init, rendered_systemd |
| `config-renderer` | Central template pipeline      | rendered_configs (map)          |

### SHARED MODULES (modules/shared/)

| Module              | Purpose                 | Key Outputs        |
| ------------------- | ----------------------- | ------------------ |
| `onepassword-secrets` | 1Password secret fetch | secrets map        |

---

## TEMPLATE RENDERING PIPELINE

```text
%% diagram: flowchart LR
  Templates["Service templates\n{NNN}-{svc}/templates/*.tftpl"] --> Renderer["config-renderer module"]
  Hosts["module.hosts.hosts"] --> Renderer
  Secrets["module.onepassword_secrets.secrets"] --> Renderer
  Renderer --> Outputs["100-pve/terraform/configs/\nGenerated files"]
  Outputs --> Deploy["SSH / provisioner deploy"]
  Deploy --> Runtime["/opt/{service}/\nRuntime config"]
```

---

## TEMPLATE INVENTORY

### By Workspace

| Workspace                      | Template                      | Purpose             | Rendered By       | Output Path                                     |
| ------------------------------ | ----------------------------- | ------------------- | ----------------- | ----------------------------------------------- |
| **105-elk**                    | docker-compose.yml.tftpl      | ELK stack           | config-renderer   | configs/lxc-105-elk/docker-compose.yml          |
|                                | Dockerfile.logstash.tftpl     | Logstash container  | config-renderer   | configs/lxc-105-elk/Dockerfile.logstash         |
|                                | filebeat.yml.tftpl            | Filebeat config     | config-renderer   | configs/lxc-105-elk/filebeat.yml                |
|                                | ilm-policy.json.tftpl         | ILM policy          | config-renderer   | configs/lxc-105-elk/ilm-policy.json             |
|                                | logstash.conf.tftpl           | Logstash pipeline   | config-renderer   | configs/lxc-105-elk/logstash.conf               |
|                                | logstash.yml.tftpl            | Logstash config     | config-renderer   | configs/lxc-105-elk/logstash.yml                |
|                                | setup-ilm.sh.tftpl            | ILM setup script    | config-renderer   | configs/lxc-105-elk/setup-ilm.sh                |
| **220-youtube**                | .env.tftpl                    | Env vars            | config-renderer   | configs/vm-220-youtube/.env                     |
|                                | docker-compose.yml.tftpl      | YouTube stack       | config-renderer   | configs/vm-220-youtube/docker-compose.yml       |
|                                | filebeat.yml.tftpl            | Filebeat config     | config-renderer   | configs/vm-220-youtube/filebeat.yml             |
| **modules/proxmox/vm-config**  | cloud-init.yaml.tftpl         | Cloud-init          | vm-config module  | (inline in VM resource)                         |
|                                | systemd.service.tftpl         | Systemd service     | vm-config module  | (inline in VM resource)                         |
| **modules/proxmox/lxc-config** | cloud-init-lxc.yaml.tftpl     | Cloud-init (LXC)    | lxc-config module | (inline in LXC resource)                        |
|                                | lxc-systemd.service.tftpl     | Systemd service     | lxc-config module | (inline in LXC resource)                        |

**Total:** 14 `.tftpl` files across 2 service workspaces and 2 module template directories.

### Template Variables (from 100-pve/terraform/main.tf)

```hcl
template_vars = {
  # Host inventory
  hosts = module.hosts.hosts

  # Service secrets (from 1Password)
  # ... consumed via module.onepassword_secrets.secrets

  # Service-specific vars
  elk_memory = local.container_sizing.elk.memory
  # ... per-service overrides
}
```

---

## PROVIDER REQUIREMENTS MATRIX

### Provider Dependency Graph

```text
%% diagram: graph LR
  PVE["100-pve"] --> Proxmox["bpg/proxmox"]
  PVE --> OnePassword["1Password/onepassword"]

  ELK["105-elk"] --> Elastic["elastic/elasticstack"]
  ELK --> OnePassword

  Synology["215-synology"] --> SynologyProvider["synology-community/synology"]
  Synology --> OnePassword

  Cloudflare["300-cloudflare"] --> CFProvider["cloudflare/cloudflare"]
  Cloudflare --> Random["hashicorp/random"]
  Cloudflare --> Time["hashicorp/time"]
  Cloudflare --> OnePassword
```

### By Workspace

| Workspace          | Provider              | Version | Auth Method           | Purpose                |
| ------------------ | --------------------- | ------- | --------------------- | ---------------------- |
| **100-pve**        | bpg/proxmox           | ~>0.94  | API token (env)       | LXC/VM provisioning    |
|                    | 1Password/onepassword | ~>3.2   | Service account (env) | Secret fetching        |
| **105-elk**        | elastic/elasticstack  | ~>0.13  | API key (env)         | Index/ILM/space mgmt   |
|                    | 1Password/onepassword | ~>3.2   | Service account (env) | Secret fetching        |
| **215-synology**   | synology-community/synology | ~>0.6 | DSM credentials (env) | NAS package/container mgmt |
|                    | 1Password/onepassword | ~>3.2   | Service account (env) | Secret fetching        |
| **300-cloudflare** | cloudflare/cloudflare | ~>5.0   | API token (env)       | DNS/tunnel/access      |
|                    | hashicorp/random      | ~>3.0   | —                     | Random values          |
|                    | hashicorp/time        | ~>0.12  | —                     | Time-based rotation    |
|                    | 1Password/onepassword | ~>3.2   | Service account (env) | Secret fetching        |

### Environment Variables (Required for CI/Local)

```bash
# Core infrastructure
export PROXMOX_VE_ENDPOINT="https://pve.jclee.me:8006"
export PROXMOX_VE_API_TOKEN="PVEAPIToken=user@pam!terraform=..."
export OP_SERVICE_ACCOUNT_TOKEN="ops_..."

# Secondary workspaces
export ELASTICSEARCH_ENDPOINTS="http://192.168.50.105:9200"
export ELASTICSEARCH_USERNAME="elastic"
export ELASTICSEARCH_PASSWORD="${ELK_ELASTIC_PASSWORD}"
export CLOUDFLARE_API_TOKEN="..."
```

---

## DATA SOURCES USED

| Data Source                                             | Workspace            | Purpose                                        |
| ------------------------------------------------------- | -------------------- | ---------------------------------------------- |
| `data "proxmox_virtual_environment_nodes"`              | 100-pve, modules/lxc, modules/vm | Validate Proxmox node availability     |
| `data "onepassword_vault"`                              | 100-pve (via module) | Resolve vault UUID by name                     |
| `data "onepassword_item"`                               | 100-pve (via module) | Fetch service secrets                          |
| `data "cloudflare_zero_trust_tunnel_cloudflared_token"` | 300-cloudflare       | Fetch tunnel tokens                            |
| `data "synology_core_network"`                          | 215-synology         | Read NAS network configuration                 |

---

## ENTRY POINT SUMMARY

### For New Contributors

1. **Understanding Infrastructure**: Start at `/home/jclee/dev/terraform/100-pve/terraform/main.tf`
2. **Host Inventory**: Read `/home/jclee/dev/terraform/100-pve/envs/prod/hosts.tf` (SSoT)
3. **Module Behavior**: Read `/home/jclee/dev/terraform/modules/proxmox/AGENTS.md`
4. **Service Config**: Check `/home/jclee/dev/terraform/{NNN}-{svc}/templates/` for template logic
5. **Rendered Outputs**: Never edit `/home/jclee/dev/terraform/100-pve/terraform/configs/` (auto-generated)

### For Workspace-Specific Work

- **Cloudflare Tunnel routes**: Edit `/home/jclee/dev/terraform/300-cloudflare/*.tf`; origins route directly to service IP:port
- **ELK pipelines**: Edit `/home/jclee/dev/terraform/105-elk/templates/logstash.conf.tftpl`
- **Cloudflare DNS**: Edit `/home/jclee/dev/terraform/300-cloudflare/main.tf`
- **Synology NAS**: Edit `/home/jclee/dev/terraform/215-synology/main.tf`

### Entrypoint Decision Tree

```text
%% diagram: flowchart TD
  Need["What do you need to change?"] --> Host["Add or modify LXC/VM"]
  Need --> Route["Add or modify ingress route"]
  Need --> Logs["Change ELK pipeline"]
  Need --> DNS["Change Cloudflare DNS / Access"]
  Need --> Module["Change reusable module"]
  Need --> Secret["Add or rotate secret"]

  Host --> PVE["Edit 100-pve/locals.tf and 100-pve/envs/prod/hosts.tf"]
  Route --> Tunnel["Edit 300-cloudflare/*.tf direct ingress"]
  Logs --> ELK["Edit 105-elk/templates/logstash.conf.tftpl"]
  DNS --> CF["Edit 300-cloudflare/*.tf"]
  Module --> Modules["Edit modules/proxmox/ or modules/shared/"]
  Secret --> Secrets["Edit modules/shared/onepassword-secrets and 1Password vault"]
```

### For Module Development

- **LXC provisioning**: `/home/jclee/dev/terraform/modules/proxmox/lxc/main.tf`
- **VM provisioning**: `/home/jclee/dev/terraform/modules/proxmox/vm/main.tf`
- **Config rendering**: `/home/jclee/dev/terraform/modules/proxmox/config-renderer/main.tf`
- **Secret fetching**: `/home/jclee/dev/terraform/modules/shared/onepassword-secrets/main.tf`

---

## CRITICAL RULES

1. **NEVER hand-edit** `/home/jclee/dev/terraform/100-pve/terraform/configs/` — regenerate via `terraform apply`
2. **ALWAYS use** `module.hosts.hosts[name].ip` for IPs (never hardcode)
3. **ALWAYS validate** with `terraform plan` before `terraform apply`
4. **ALWAYS source** templates from workspace `templates/` directories
5. **ALWAYS inject secrets** via environment variables (never in `.tf` files)
6. **NEVER commit** `.tfvars`, `.env`, `.tfstate`, or API keys
