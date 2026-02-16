# PROXMOX MODULES KNOWLEDGE BASE

**Location:** `modules/proxmox/`
**Status:** Core Infrastructure Logic
**Style:** Google3 Telegraphic

## OVERVIEW
Unified IaC pipeline for Proxmox resource lifecycle. Abstracted layer between global host inventory and raw `bpg/proxmox` provider resources. Orchestrates config rendering, hardware provisioning, and environment mapping.

## STRUCTURE
- `lxc/`: Direct PCT container provisioning (CPU, RAM, Storage, Network).
- `vm/`: QEMU VM provisioning (CPU, RAM, Storage, Cloud-init).
- `lxc-config/`: Container-level configuration snippet generation.
- `vm-config/`: VM-level configuration rendering (Cloud-init templates).
- `config-renderer/`: Central pipeline for rendering `.tftpl` to service configs.

## WHERE TO LOOK (Config Flow)
1. **Source:** `100-pve/envs/prod/hosts.tf` defines IDs, IPs, and service metadata (SSoT).
2. **Templating:** `config-renderer/` renders `.tftpl` with `hosts` map + inline vars from `main.tf`.
3. **Deployment:** `lxc/` or `vm/` provisions hardware; `lxc-config/` or `vm-config/` deploys rendered configs.

## CONVENTIONS
- **Templates:** App-level logic belongs in `templates/*.tftpl`. Never in `.tf`.
- **Variables:** `variables.tf` strictly for hardware/provider knobs.
- **Paths:** Always use relative paths (`path.module`) for template resolution.
- **Naming:** Module aliases must match `VMID-service` convention.
- **ID Management:** VMIDs are derived from `hosts.tf` SSoT to prevent collisions.

## ANTI-PATTERNS
- **NO Hardcoded IPs:** All network config must flow from `module.hosts` (100-pve/envs/prod/hosts.tf).
- **NO Direct Resource Usage:** Use modules for all `proxmox_virtual_environment_*`.
- **NO Manual Snippets:** Config files must be rendered via `config-renderer`.
- **NO Inline Cloud-Init:** Use external templates for readability and linting.
- **NO Local-Exec:** Prefer `proxmox_virtual_environment_file` for config delivery.
