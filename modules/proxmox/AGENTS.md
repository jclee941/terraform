# PROXMOX MODULES KNOWLEDGE BASE

**Location:** `modules/proxmox/`
**Status:** Core Infrastructure Logic
**Style:** Google3 Telegraphic

## OVERVIEW
Unified IaC pipeline for Proxmox resource lifecycle. Abstracted layer between global host inventory and raw `bpg/proxmox` provider resources. Orchestrates config rendering, hardware provisioning, and environment mapping.

## STRUCTURE
- `lxc/`: Direct PCT container provisioning (CPU, RAM, Storage, Network).
- `lxc-config/`: Container-level configuration snippet generation.
- `vm-config/`: VM-level lifecycle (Cloud-init rendering, hardware specs).
- `env-config/`: Maps host inventory metadata to module-compatible inputs.
- `config-renderer/`: Central pipeline for rendering `.tftpl` to service configs.
- `inventory/`: SSoT for resource allocation, ID management, and IP assignments.

## WHERE TO LOOK (Config Flow)
1. **Source:** `inventory/` defines IDs, IPs, and service metadata.
2. **Mapping:** `env-config/` transforms inventory data into typed objects.
3. **Templating:** `config-renderer/` fetches `.tftpl` and injects env-config data.
4. **Deployment:** `lxc/` or `vm-config/` consumes rendered strings for final state.

## CONVENTIONS
- **Templates:** App-level logic belongs in `templates/*.tftpl`. Never in `.tf`.
- **Variables:** `variables.tf` strictly for hardware/provider knobs.
- **Paths:** Always use relative paths (`path.module`) for template resolution.
- **Naming:** Module aliases must match `VMID-service` convention.
- **ID Management:** VMIDs are derived from `inventory` to prevent collisions.

## ANTI-PATTERNS
- **NO Hardcoded IPs:** All network config must flow from `module.inventory`.
- **NO Direct Resource Usage:** Use modules for all `proxmox_virtual_environment_*`.
- **NO Manual Snippets:** Config files must be rendered via `config-renderer`.
- **NO Inline Cloud-Init:** Use external templates for readability and linting.
- **NO Local-Exec:** Prefer `proxmox_virtual_environment_file` for config delivery.
