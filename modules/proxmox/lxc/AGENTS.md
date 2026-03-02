# AGENTS: modules/proxmox/lxc - LXC Provisioning

## OVERVIEW
Provisioning module for Proxmox LXC containers with strict input validation and lifecycle protections.

## STRUCTURE
```text
lxc/
├── main.tf
├── variables.tf
├── outputs.tf
└── AGENTS.md
```

## INTERFACE
| Kind | Name | Type | Required | Description |
|------|------|------|----------|-------------|
| variable | `node_name` | `string` | Yes | Proxmox node target for container deployment. |
| variable | `vmid` | `number` | Yes | Container ID (validated 100-999 and managed range). |
| variable | `hostname` | `string` | Yes | DNS-safe LXC hostname label. |
| variable | `ip_address` | `string` | Yes | Static IPv4 address (without CIDR suffix). |
| variable | `memory` | `number` | Yes | Dedicated RAM in MB (validated bounds). |
| variable | `datastore_id` | `string` | Yes | Storage backend for root disk. |
| variable | `template_file_id` | `string` | No | LXC template reference (`storage:vztmpl/...`). |
| output | `vmid` | - | - | Provisioned container VMID. |
| output | `ip_address` | - | - | Container IP passed from module input. |
| output | `status` | - | - | Started state + node summary map. |
See `variables.tf` for full list.

## CONSUMERS
- Called by `100-pve/main.tf` via `module.lxc`.

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
