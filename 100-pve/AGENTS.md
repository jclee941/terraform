# AGENTS: 100-pve — Primary Terraform Workspace

## OVERVIEW

Central Terraform workspace orchestrating ALL Proxmox infrastructure. Provisions 8 LXC containers (101-108) and 4 VMs (109, 112, 200, 220) via reusable modules. Split across `main.tf` (77 lines — providers, host inventory, LXC/VM modules), `vm_configs.tf` (143 lines — VM config deployment), `lxc_configs.tf` (261 lines — LXC config deployment), `secrets.tf` (66 lines — 1Password secrets + config renderer), `locals.tf` (311 lines), `checks.tf` (79 lines), `outputs.tf` (88 lines), `data.tf` (5 lines), and `firewall.tf` (156 lines).

## STRUCTURE

```
100-pve/
├── main.tf              # Providers, host inventory, LXC/VM modules, moved blocks (77 lines)
├── vm_configs.tf        # VM config deployment modules (143 lines)
├── lxc_configs.tf       # LXC config deployment modules (262 lines)
├── secrets.tf           # 1Password secrets + config renderer (66 lines)
├── locals.tf            # All locals: sizing, VM defs, config maps (311 lines)
├── checks.tf            # TF 1.5+ check blocks: validation (79 lines)
├── variables.tf         # Input variables + validation
├── versions.tf          # Provider + backend config (local)
├── terraform.tfvars     # Variable values (gitignored)
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
| **Container Sizing** | `locals.tf` → `container_sizing`        | Memory, swap, cores, disk. Budget: 16.3 GB + 9.3 GB swap.     |
| **VM Definitions**   | `locals.tf` → `vm_definitions`          | QEMU VMs (mcphub=112). Cloud-init refs in `cloud_init_files`. |
| **Validation**       | `checks.tf`                             | VMID range, IP subnet, memory (TF 1.5+ checks).               |
| **LXC Provisioning** | `module.lxc`                            | `../modules/proxmox/lxc` — all 8 containers.                  |
| **VM Provisioning**  | `module.vm`                             | `../modules/proxmox/vm` — cloud-init via snippets.            |
| **Config Rendering** | `vm_configs.tf`, `lxc_configs.tf`       | Renders service templates → `configs/`.                       |
| **Rendered Outputs** | `configs/lxc-{VMID}-{name}/`            | Terraform-generated. Never hand-edit.                         |
| **Firewall Rules**   | `firewall.tf`                           | Cluster + VM-level firewall security groups.                  |
| **Filebeat Configs** | `config/`                               | Host-level Filebeat configuration templates.                  |
| **Filebeat Deploy**  | `lxc_configs.tf`, `vm_configs.tf`       | `setup_filebeat` provisioner in deploy modules.               |

## DATA FLOW

```
envs/prod/hosts.tf (SSoT)
  → module.hosts (exposes IPs/ports/roles)
    → locals.tf (merges sizing + inventory)
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
