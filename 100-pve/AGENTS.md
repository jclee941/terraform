# AGENTS: 100-pve — Primary Terraform Workspace

## OVERVIEW

Central Terraform workspace orchestrating Proxmox infrastructure. The live Terraform root is `100-pve/terraform/`; host inventory stays in `100-pve/envs/prod/hosts.tf`.

## STRUCTURE

```
100-pve/
├── terraform/
│   ├── main.tf          # Providers, host inventory, LXC/VM modules, moved blocks
│   ├── vm_configs.tf    # VM config deployment modules
│   ├── lxc_configs.tf   # LXC config deployment modules
│   ├── secrets.tf       # 1Password secrets + config renderer
│   ├── locals.tf        # Sizing, VM defs, config maps
│   ├── checks.tf        # TF check blocks
│   ├── variables.tf     # Input variables + validation
│   ├── versions.tf      # Provider + local backend config
│   └── configs/         # TF-rendered outputs (NOT hand-editable)
├── envs/prod/
│   └── hosts.tf         # SSoT: ALL host IPs, ports, roles, VMIDs
├── config/              # Host-level Filebeat configs
└── pve-hacks/           # Manual hypervisor scripts/workarounds
```

## WHERE TO LOOK

| Task                 | Location                                | Notes                                                         |
| -------------------- | --------------------------------------- | ------------------------------------------------------------- |
| **All IPs/Ports**    | `envs/prod/hosts.tf`                    | SSoT. `module.hosts.hosts[name].{ip,vmid,ports,roles}`.       |
| **Container Sizing** | `terraform/locals.tf` → `container_sizing` | Active LXC sizing entries: elk and cliproxy. |
| **VM Definitions**   | `terraform/locals.tf` → `vm_definitions` | Two QEMU VMs: oc and youtube. |
| **Validation**       | `terraform/checks.tf`                   | VMID range, IP subnet, memory checks.                         |
| **LXC Provisioning** | `terraform/main.tf` → `module.lxc`      | Calls `../../modules/proxmox/lxc` for `local.containers`.     |
| **VM Provisioning**  | `terraform/main.tf` → `module.vm`       | Calls `../../modules/proxmox/vm` for `local.vm_definitions`.  |
| **Config Rendering** | `terraform/vm_configs.tf`, `terraform/lxc_configs.tf` | Renders service templates → `terraform/configs/`. |
| **Rendered Outputs** | `terraform/configs/lxc-{VMID}-{name}/`, `terraform/configs/rendered/` | Terraform-generated. Never hand-edit. |
| **Firewall Rules**   | `terraform/firewall.tf`                 | Cluster + VM-level firewall security groups.                  |
| **Filebeat Configs** | `config/`                               | Host-level Filebeat configuration templates.                  |
| **Filebeat Deploy**  | `terraform/lxc_configs.tf`, `terraform/vm_configs.tf` | `setup_filebeat` provisioner in deploy modules. |

## DATA FLOW

```
envs/prod/hosts.tf (SSoT)
  → module.hosts (exposes IPs/ports/roles)
    → terraform/locals.tf (merges sizing + inventory)
      → module.lxc / module.vm (provisions infra)
      → module.lxc_config / module.vm_config (renders + deploys service configs + Filebeat)
        → terraform/configs/ (outputs pushed to guests)
```

## CONVENTIONS

- **No Hardcoded IPs**: All IPs via `module.hosts.hosts[name].ip`.
- **Module Sources**: `../../modules/proxmox/{lxc,vm,*-config}` from the `terraform/` root.
- **Template Paths**: `${path.module}/../../{NNN}-{svc}/templates/`.
- **Memory Budget**: Total < 54 GB physical. Sizing in `container_sizing` local.
- **Providers**: `bpg/proxmox` (~>0.94), `1Password/onepassword` (~>3.2).
- **Filebeat**: All LXC/VM hosts get Filebeat via `setup_filebeat` provisioner. Logs flow to Logstash on 105.
- **Firewall**: `terraform/firewall.tf` uses `var.node_name` for node targeting — never hardcode `"pve"`.

## ANTI-PATTERNS

- **NO hand-editing** `terraform/configs/` — regenerate via Terraform workflows.
- **NO hardcoded IPs** in Terraform files — use `module.hosts`.
- **NO UI changes** on TF-managed guests from `local.containers` or `local.vm_definitions`. Causes drift.
- **NO direct state edits** — use `terraform import/state mv`.

## COMMANDS

```bash
make plan SVC=pve             # Plan changes
# make apply is DISABLED locally — all applies go through CI/CD
```
