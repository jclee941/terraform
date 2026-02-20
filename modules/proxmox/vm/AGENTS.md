# AGENTS: modules/proxmox/vm - VM Provisioning

## OVERVIEW
Provisioning module for Proxmox VMs using clone and cloud-init inputs with validation on hardware and network boundaries.

## WHERE TO LOOK
| Task | File | Notes |
|------|------|-------|
| VM resource lifecycle | `main.tf` | `proxmox_virtual_environment_vm` clone/init blocks and lifecycle guards. |
| Input validation | `variables.tf` | Clone template ID, BIOS/machine, CPU/memory/disk, network rules. |
| Output contract | `outputs.tf` | VM identity/status consumed by vm-config and workspace outputs. |

## CONVENTIONS
- Keep cloud-init file IDs passed from upstream render/deploy steps.
- Keep clone semantics explicit; avoid implicit defaults for template source.
- Keep validation rules aligned with workspace-managed VMID ranges.

## ANTI-PATTERNS
- Do not hardcode template IDs directly in service workspaces.
- Do not disable lifecycle protections to force resource replacement.
- Do not couple VM provisioning with service file deployment logic.
