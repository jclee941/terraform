# PC to Proxmox Migration via PXE Boot

## Overview

This guide documents the process of converting a PC to a Proxmox VE node using PXE network boot with Synology NAS as the PXE server.

## Prerequisites

### Hardware Requirements
- **Target PC**: 64-bit CPU with VT-x/AMD-V support, 8GB+ RAM, 100GB+ disk
- **Synology NAS**: VMID 215 (192.168.50.215) with DSM 7.x
- **Network**: 192.168.50.0/24 subnet, DHCP available

### Software Requirements
- Proxmox VE 8.2 ISO
- SSH access to Synology NAS (admin privileges)
- 1Password CLI for secret injection

## Phase 1: Synology PXE Server Setup

### 1.1 Enable TFTP Service

```bash
# SSH to Synology NAS
ssh admin@192.168.50.215

# Create TFTP root directory
sudo mkdir -p /volume1/tftpboot
sudo chmod 755 /volume1/tftpboot

# Enable TFTP service
sudo synoservice --enable tftp
sudo synoservice --start tftp

# Verify status
sudo synoservice --status tftp
```

### 1.2 Configure DHCP Options

**Option A: Synology DHCP Server**
```
DSM Control Panel → Network → DHCP Server
```

Add DHCP options:
- **Option 66 (TFTP Server Name)**: `192.168.50.215`
- **Option 67 (Bootfile Name)**: `grubx64.efi`

**Option B: External DHCP (pfSense/OPNsense)**
```
DHCP Options:
- 66: 192.168.50.215
- 67: grubx64.efi
```

### 1.3 Directory Structure

```
/volume1/tftpboot/
├── grubx64.efi              # UEFI bootloader
├── grub/
│   └── grub.cfg             # GRUB menu configuration
└── proxmox/
    ├── linux26              # Proxmox kernel
    └── initrd.img           # Custom initrd with embedded ISO
```

## Phase 2: Proxmox Boot Media Preparation

### 2.1 Download and Extract ISO

```bash
# On workstation or Synology
wget https://enterprise.proxmox.com/iso/proxmox-ve_8.2-2.iso \
  -O /volume1/shared/proxmox-ve_8.2-2.iso

# Mount and extract
mkdir -p /mnt/iso
sudo mount -o loop /volume1/shared/proxmox-ve_8.2-2.iso /mnt/iso

# Copy boot files
sudo cp /mnt/iso/boot/linux26 /volume1/tftpboot/proxmox/
sudo cp /mnt/iso/boot/initrd.img /volume1/tftpboot/proxmox/initrd-original.img
```

### 2.2 Create Automated Installation Answer File

See: `../100-pve/configs/proxmox-answer.toml`

### 2.3 Build Custom Initrd

```bash
cd /tmp
mkdir initrd-extract && cd initrd-extract

# Extract original initrd
zstd -d /volume1/tftpboot/proxmox/initrd-original.img -o initrd.cpio
cpio -idv < initrd.cpio

# Embed automated ISO
cp /volume1/shared/proxmox-ve-auto.iso ./proxmox.iso

# Repack initrd
find . | cpio --quiet -o -H newc > ../custom-initrd.cpio
zstd -5 ../custom-initrd.cpio -o /volume1/tftpboot/proxmox/initrd.img
```

### 2.4 Configure GRUB2

**grub.cfg** (`/volume1/tftpboot/grub/grub.cfg`):

```grub
set timeout=10
set default=0

insmod net
insmod efinet
insmod tftp
insmod gzio

menuentry "Proxmox VE 8.2 - Automated Install (pve2)" {
    echo "Loading kernel..."
    linux /proxmox/linux26 \
        ro \
        ramdisk_size=16777216 \
        rw \
        quiet \
        splash=silent \
        proxmox-start-auto-installer
    
    echo "Loading initrd..."
    initrd /proxmox/initrd.img
    
    echo "Booting..."
}

menuentry "Proxmox VE 8.2 - Debug Mode" {
    linux /proxmox/linux26 \
        ro \
        ramdisk_size=16777216 \
        rw \
        splash=verbose \
        proxdebug
    initrd /proxmox/initrd.img
}
```

## Phase 3: Target PC Configuration

### 3.1 BIOS/UEFI Settings

1. Enter BIOS setup (F2/F10/F12/Del)
2. Enable **Virtualization Technology** (VT-x/AMD-V)
3. Enable **Network Boot** (PXE)
4. Set boot priority: Network first
5. For UEFI: Enable **UEFI Network Stack**
6. Save and exit

### 3.2 PXE Boot Process

Expected sequence:
1. PC POST completes
2. Network adapter initializes PXE
3. DHCP request → receives IP + boot server (192.168.50.215)
4. TFTP download of `grubx64.efi`
5. GRUB menu appears → select automated install
6. Kernel + initrd downloaded
7. Proxmox automated installation begins

### 3.3 Post-Installation

After automated install completes:
1. PC reboots automatically
2. Proxmox VE boots from local disk
3. Web UI accessible at: `https://192.168.50.250:8006/`
4. Verify installation:

```bash
# SSH to new node
ssh root@192.168.50.250

# Check version
pveversion

# Check ZFS pool
zpool status

# Check cluster (initially standalone)
pvecm status
```

## Phase 4: Terraform Integration

### 4.1 Update hosts.tf

Add pve2 to `100-pve/envs/prod/hosts.tf`:

```hcl
pve2 = {
  vmid  = 250
  ip    = "192.168.50.250"
  roles = ["hypervisor", "pve-node"]
  ports = {
    pve_https = 8006
    pve_spice = 3128
  }
}
```

### 4.2 Configure Multi-Node Provider

Add to `100-pve/terraform/main.tf`:

```hcl
provider "proxmox" {
  alias     = "pve2"
  endpoint  = "https://192.168.50.250:8006/"
  api_token = local.effective_proxmox_api_token
  insecure  = var.proxmox_insecure
}
```

### 4.3 Create API Token on pve2

```bash
# On pve2 node
pveum user add terraform@pve --password <temp>
pveum role add TerraformAdmin --privs "VM.Allocate VM.Clone VM.Config.* VM.Console VM.Migrate VM.PowerMgmt Datastore.Allocate* Pool.Allocate SDN.Use Sys.Audit Sys.Console"
pveum aclmod / -user terraform@pve -role TerraformAdmin
pveum token add terraform@pve terraform-token --privsep=0
```

## Troubleshooting

### PXE Boot Fails

```bash
# Check TFTP logs on Synology
cat /var/log/tftp.log

# Test TFTP manually
tftp 192.168.50.215
tftp> get grubx64.efi
```

### DHCP Issues

```bash
# Verify DHCP options
dhcping -c 192.168.50.250 -s 192.168.50.215
```

### Initrd Too Large

Use higher compression:
```bash
zstd -19 custom-initrd.cpio -o /volume1/tftpboot/proxmox/initrd.img
```

### ZFS Disk Detection

Use `device-info` to get exact disk IDs for answer file.

## Verification Checklist

- [ ] Synology TFTP service running
- [ ] DHCP options 66/67 configured
- [ ] Boot files in /volume1/tftpboot/
- [ ] Target PC network boot enabled
- [ ] GRUB menu appears on PXE boot
- [ ] Automated installation completes
- [ ] pve2 accessible via SSH and Web UI
- [ ] Terraform provider alias configured
- [ ] API token created on pve2

## References

- [Proxmox PXE Boot Documentation](https://pve.proxmox.com/wiki/PXE_Boot_Server)
- [Proxmox Automated Installation](https://pve.proxmox.com/wiki/Automated_Installation)
- [Synology TFTP Service](https://kb.synology.com/en-global/DSM/help/FileStation/file_modify)
