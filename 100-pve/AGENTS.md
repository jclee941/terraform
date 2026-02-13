# AGENTS: 100-pve (Proxmox Host)

## OVERVIEW
Proxmox Virtual Environment (PVE) host node `100`.
- **IP Address**: `192.168.50.100`
- **Role**: Primary hypervisor hosting all LXC containers and Virtual Machines for the homelab.
- **Management**: Manual configuration layer. This node provides the hardware abstraction and virtualization services that the rest of the infrastructure depends on.

## STRUCTURE
- `config/`: Host-level configuration files and templates (e.g., Filebeat).
- `pve-hacks/`: Manual scripts, workarounds, and maintenance tools for the hypervisor host.
- `scripts/`: Legacy maintenance tasks (scrubs, backups, thermal monitoring).

## WHERE TO LOOK
- **Hardware Config**: `/etc/pve/` (Cluster-wide config filesystem).
- **Network Interface**: `/etc/network/interfaces` (Physical and bridge networking).
- **Storage Profile**: `/etc/pve/storage.cfg` (ZFS, LVM, and NFS definitions).
- **Guest Configuration**: `/etc/pve/lxc/*.conf` or `/etc/pve/qemu-server/*.conf`.
- **System Logs**: `journalctl -f` or `/var/log/syslog` for host-level diagnostics.

## CONVENTIONS
- **Manual Only**: All changes to the hypervisor host OS and hardware configuration are strictly manual.
- **No Terraform**: This directory is NOT managed by Terraform. Do not attempt to use IaC for host-level OS tuning.
- **VMID Mapping**: Guest IDs must correspond to the directory numbering (e.g., Traefik on 102).
- **Security**: Root SSH access is restricted to the management VLAN/LAN.

## ANTI-PATTERNS
- **No Direct TF Application**: Do not attempt to manage host-level packages or kernel parameters via the project's main Terraform orchestration.
- **No UI Drift**: Avoid changing guest resource allocations via the Proxmox Web UI for guests managed by Terraform (101-220).
- **No Plaintext Secrets**: Never hardcode credentials in `pve-hacks/` scripts.
- **No Unshadowed Changes**: Any manual tweak to the host that affects guest automation must be documented here.
