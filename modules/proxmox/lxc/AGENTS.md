# AGENTS: modules/proxmox/lxc - LXC Provisioning

## OVERVIEW
Provisioning module for Proxmox LXC containers with strict input validation and lifecycle protections.

## WHERE TO LOOK
| Task | File | Notes |
|------|------|-------|
| Container resource lifecycle | `main.tf` | `proxmox_virtual_environment_container` lifecycle checks and ignore rules. |
| Input constraints | `variables.tf` | VMID range, memory, CPU, disk, and network validation. |
| Module outputs | `outputs.tf` | `vmid`, `ip_address`, `status` interface for downstream modules. |

## CONVENTIONS
- Derive VMID/IP from `100-pve/envs/prod/hosts.tf` via parent workspace.
- Keep provider-facing defaults conservative; fail fast on invalid ranges.
- Preserve lifecycle preconditions/postconditions for drift-safe operations.

## ANTI-PATTERNS
- Do not bypass this module with direct LXC resources in workspaces.
- Do not relax validation guards to pass transient plan failures.
- Do not embed service config rendering logic here.
