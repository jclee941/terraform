# AGENTS: modules/proxmox/vm - VM Provisioning

## OVERVIEW
Provisioning module for Proxmox VMs using clone and cloud-init inputs with validation on hardware and network boundaries.

## STRUCTURE
```text
vm/
├── main.tf
├── variables.tf
├── outputs.tf
└── AGENTS.md
```

## INTERFACE
| Kind | Name | Type | Required | Description |
|------|------|------|----------|-------------|
| variable | `node_name` | `string` | Yes | Proxmox node hosting the VM resource. |
| variable | `vmid` | `number` | Yes | VMID with validation and lifecycle range checks. |
| variable | `hostname` | `string` | Yes | VM name used for guest identity and resource naming. |
| variable | `clone_template_id` | `number` | No | Source template VMID for full clone operations. |
| variable | `cloud_init_file_id` | `string` | No | Snippet file ID for cloud-init user-data injection. |
| variable | `bios` | `string` | No | Firmware mode (`seabios` or `ovmf`). |
| variable | `hostpci_devices` | `list(object)` | No | Optional PCI passthrough devices for workloads. |
| output | `vmid` | - | - | Provisioned VM ID. |
| output | `ip_address` | - | - | VM IP passed from module input. |
| output | `status` | - | - | Started state + node summary map. |
See `variables.tf` for full list.

## CONSUMERS
- Called by `100-pve/main.tf` via `module.vm`.

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
- EFI disk (`efi_disk`) uses dynamic block — only rendered when `bios = "ovmf"`. Do not add static `efi_disk` blocks.

## ANTI-PATTERNS
- Do not hardcode template IDs directly in service workspaces.
- Do not disable lifecycle protections to force resource replacement.
- Do not couple VM provisioning with service file deployment logic.
