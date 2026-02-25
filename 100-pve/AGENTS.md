# AGENTS: 100-pve — Primary Terraform Workspace

## OVERVIEW

Central Terraform workspace orchestrating ALL Proxmox infrastructure. Provisions 7 LXC containers (101-108) and VMs (112) via reusable modules. `main.tf` (958 lines) coordinates host inventory, container sizing, validation, config rendering, and Filebeat deployment. `firewall.tf` (130 lines) defines Proxmox firewall rules for cluster and VM-level security groups.

## STRUCTURE

```
100-pve/
├── main.tf              # Central orchestration (958 lines)
├── firewall.tf          # Proxmox firewall rules + security groups (130 lines)
├── variables.tf         # Input variables + validation
├── terraform.tfvars     # Variable values (gitignored)
├── versions.tf          # Provider + backend config (local)
├── envs/prod/
│   └── hosts.tf         # SSoT: ALL host IPs, ports, roles, VMIDs
├── configs/             # TF-rendered outputs (NOT hand-editable)
│   ├── lxc-{VMID}-{name}/  # Per-container rendered configs
│   └── rendered/        # Traefik dynamic routes, etc.
├── config/              # Host-level Filebeat configs
└── pve-hacks/           # Manual hypervisor scripts/workarounds
```

## WHERE TO LOOK

| Task                 | Location                                | Notes                                                         |
| -------------------- | --------------------------------------- | ------------------------------------------------------------- |
| **All IPs/Ports**    | `envs/prod/hosts.tf`                    | SSoT. `module.hosts.hosts[name].{ip,vmid,ports,roles}`.       |
| **Container Sizing** | `main.tf` → `container_sizing`          | Memory, swap, cores, disk. Budget: 16.3 GB + 9.3 GB swap.     |
| **VM Definitions**   | `main.tf` → `vm_definitions`            | QEMU VMs (mcphub=112). Cloud-init refs in `cloud_init_files`. |
| **Validation**       | `main.tf` check blocks                  | VMID range, IP subnet, memory (TF 1.5+ checks).               |
| **LXC Provisioning** | `module.lxc`                            | `../modules/proxmox/lxc` — all 7 containers.                  |
| **VM Provisioning**  | `module.vm`                             | `../modules/proxmox/vm` — cloud-init via snippets.            |
| **Config Rendering** | `module.vm_config`                      | Renders service templates → `configs/`.                       |
| **Rendered Outputs** | `configs/lxc-{VMID}-{name}/`            | Terraform-generated. Never hand-edit.                         |
| **Firewall Rules**   | `firewall.tf`                           | Cluster + VM-level firewall security groups.                  |
| **Filebeat Configs** | `config/`                               | Host-level Filebeat configuration templates.                  |
| **Filebeat Deploy**  | `module.lxc_config`, `module.vm_config` | `setup_filebeat` provisioner in deploy modules.               |

## DATA FLOW

```
envs/prod/hosts.tf (SSoT)
  → module.hosts (exposes IPs/ports/roles)
    → main.tf locals (merges sizing + inventory)
      → module.lxc / module.vm (provisions infra)
      → module.lxc_config / module.vm_config (renders + deploys service configs + Filebeat)
        → configs/ (outputs pushed to guests)
```

## CONVENTIONS

- **No Hardcoded IPs**: All IPs via `module.hosts.hosts[name].ip`.
- **Module Sources**: `../modules/proxmox/{lxc,vm,*-config}` relative paths.
- **Template Paths**: `${path.module}/../{NNN}-{svc}/templates/`.
- **Memory Budget**: Total < 54 GB physical. Sizing in `container_sizing` local.
- **Providers**: `bpg/proxmox` (~>0.94), `1Password/onepassword` (~>3.2).
- **Filebeat**: All LXC/VM hosts get Filebeat via `setup_filebeat` provisioner. Logs flow to Logstash on 105.
- **Firewall**: `firewall.tf` uses `var.node_name` for node targeting — never hardcode `"pve"`.

## ANTI-PATTERNS

- **NO hand-editing** `configs/` — regenerate via `terraform apply`.
- **NO hardcoded IPs** in main.tf — use `module.hosts`.
- **NO UI changes** on TF-managed guests (101-108, 112). Causes drift.
- **NO direct state edits** — use `terraform import/state mv`.

## COMMANDS

```bash
make plan SVC=pve             # Plan changes
make apply SVC=pve            # Apply
terraform plan -out=tfplan    # Direct (from 100-pve/)
terraform apply tfplan
```
