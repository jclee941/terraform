# 100-pve: Proxmox Hypervisor Host

## 1. Service Overview
- **Service Name**: Proxmox VE (PVE)
- **Host IP**: `192.168.50.100`
- **Purpose**: Central hypervisor node for the `jclee.me` homelab. It orchestrates Terraform-managed LXC containers (101, 102, 104-108) and VM 112 (MCPHub).
- **Current Status**: **Online**. Hosting critical infrastructure including Traefik, ELK, and MCPHub.
- **Hardware Profile**:
  - **CPU**: Ryzen 9800X3D (8-Core/16-Thread)
  - **RAM**: 60GB DDR5
  - **Storage**: local (ISO/Templates), local-lvm (VM/CT Disks)

## 2. Configuration Files
Proxmox configurations are primarily located on the host filesystem:
- **LXC Container Configs**: `/etc/pve/lxc/*.conf` - Defines CPU, MEM, Network, and mount points for containers.
- **VM Configs**: `/etc/pve/qemu-server/*.conf` - Hardware definitions for virtual machines (e.g., 200-oc).
- **Storage Definitions**: `/etc/pve/storage.cfg` - Manages backend storage pools (LVM, ZFS, NFS).
- **Network Interfaces**: `/etc/network/interfaces` - Linux Bridge (`vmbr0`) and VLAN configurations.
- **Local Scripts**: `/home/jclee/proxmox/100-pve/scripts/` - Maintenance and backup automation.

## 3. Operations
Operations are performed via SSH or the Proxmox Web UI (https://192.168.50.100:8006).

### Lifecycle Commands
```bash
# SSH into the host
ssh pve

# Manage LXC Containers
pct list                      # Show status of all containers
pct start <VMID>              # Start container (e.g., pct start 102)
pct stop <VMID>               # Graceful shutdown
pct enter <VMID>              # Open a shell inside the container

# Manage Virtual Machines
qm list                       # Show status of all VMs
qm start <VMID>               # Power on VM (e.g., qm start 200)
qm shutdown <VMID>            # Graceful ACPI shutdown
```

### Logging
- **System Logs**: `journalctl -f`
- **Task Logs**: `/var/log/pve/tasks/`
- **Cluster Logs**: `/var/log/pveproxy/access.log`

## 4. Dependencies
As the host node, 100-pve is the foundation for:
- **102-traefik**: Provides ingress to all web services.
- **terraform**: Manages containers 101, 102, 104-108 and VM 112 on this host.
- **112-mcphub**: MCP Hub + AI/Tools (VM).
- **Network**: Depends on the physical gateway at `192.168.50.1`.

## 5. Troubleshooting
### Common Issues
- **LXC Start Failure**: Check for unprivileged container mapping issues or missing mount points.
  - *Fix*: `pct start <VMID>` and check `/var/log/syslog`.
- **High Memory Pressure**: ELK (105) or MCPHub (112) can consume excessive RAM.
  - *Fix*: Monitor with `htop` on the host; restart offending container if necessary.
- **Terraform Drift**: Manual changes in the Proxmox UI will be overwritten by terraform.
  - *Fix*: Always update `main.tf` in the `terraform` directory instead of using the UI.
- **IO Delay**: High IO wait usually indicates intensive backup jobs or heavy Elasticsearch indexing on ELK (105).

## 6. Governance
- **Style**: Google3 Monorepo
- **Build System**: Bazel (`BUILD.bazel` included for config validation)
- **Ownership**: Infrastructure Team (see `OWNERS`)
