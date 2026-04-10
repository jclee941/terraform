#!/bin/bash
# Synology PXE Setup Script
# Run this script on Synology NAS (192.168.50.215) as jclee user with sudo

set -e

echo "=== Synology PXE Server Setup ==="
echo "Target: Proxmox VE 9.1 auto-install for pve2"
echo ""

# 1. Stop conflicting TFTP processes
echo "[1/8] Stopping conflicting TFTP..."
sudo pkill opentftp 2>/dev/null || true
sleep 2

# 2. Create directory structure
echo "[2/8] Creating directory structure..."
sudo mkdir -p /volume1/tftpboot/{proxmox,grub,pxelinux.cfg}
sudo chmod 755 /volume1/tftpboot

# 3. Mount ISO and extract boot files
echo "[3/8] Extracting boot files from ISO..."
ISO_PATH="/volume1/@appdata/ContainerManager/all_shares/data/iso/proxmox-ve_9.1-1.iso"
MOUNT_POINT="/tmp/proxmox-iso"

sudo mkdir -p $MOUNT_POINT
sudo mount -o loop $ISO_PATH $MOUNT_POINT
sudo cp $MOUNT_POINT/boot/linux26 /volume1/tftpboot/proxmox/
sudo cp $MOUNT_POINT/boot/initrd.img /volume1/tftpboot/proxmox/initrd-original.img

# 4. Create answer.toml
echo "[4/8] Creating answer.toml..."
sudo tee /volume1/tftpboot/proxmox/answer.toml >/dev/null <<'EOF'
[global]
keyboard = "en-us"
country = "KR"
fqdn = "pve2.jclee.me"
mailto = "admin@jclee.me"
timezone = "Asia/Seoul"
root-password = "CHANGEME_AFTER_INSTALL"
reboot-on-error = true
reboot-mode = "reboot"

[network]
source = "from-dhcp"

[network.interface-name-pinning]
enabled = true

[disk-setup]
filesystem = "zfs"
zfs.raid = "single"
zfs.hdsize = 500

[first-boot]
source = "from-iso"
ordering = "fully-up"
EOF

# 5. Create embedded initrd
echo "[5/8] Creating embedded initrd (this may take 2-3 minutes)..."
cd /tmp
sudo rm -rf initrd-work
sudo mkdir initrd-work && cd initrd-work

# Extract original initrd
if file /volume1/tftpboot/proxmox/initrd-original.img | grep -q "Zstandard"; then
  sudo zstd -d /volume1/tftpboot/proxmox/initrd-original.img -o initrd.cpio
elif file /volume1/tftpboot/proxmox/initrd-original.img | grep -q "gzip"; then
  sudo gzip -dc /volume1/tftpboot/proxmox/initrd-original.img >initrd.cpio
else
  sudo cp /volume1/tftpboot/proxmox/initrd-original.img initrd.cpio
fi

sudo cpio -id <initrd.cpio 2>/dev/null || true

# Embed ISO and answer file
sudo cp $ISO_PATH ./proxmox.iso
sudo cp /volume1/tftpboot/proxmox/answer.toml ./answer.toml

# Repack with gzip (zstd may not be available)
sudo find . | sudo cpio -o -H newc 2>/dev/null | sudo gzip -9 >/tmp/initrd-new.img
sudo cp /tmp/initrd-new.img /volume1/tftpboot/proxmox/initrd.img

# 6. Create GRUB config
echo "[6/8] Creating GRUB configuration..."
sudo tee /volume1/tftpboot/grub/grub.cfg >/dev/null <<'EOF'
set timeout=10
set default=0

menuentry "Proxmox VE 9.1 - Automated Install (pve2)" {
    linux /proxmox/linux26 ro ramdisk_size=16777216 rw quiet splash=silent proxmox-start-auto-installer
    initrd /proxmox/initrd.img
}

menuentry "Proxmox VE 9.1 - Debug Mode" {
    linux /proxmox/linux26 ro ramdisk_size=16777216 rw splash=verbose proxdebug
    initrd /proxmox/initrd.img
}

menuentry "Local Boot" {
    exit
}
EOF

# 7. Copy GRUB EFI
echo "[7/8] Copying GRUB EFI bootloader..."
if [ -f $MOUNT_POINT/EFI/boot/bootx64.efi ]; then
  sudo cp $MOUNT_POINT/EFI/boot/bootx64.efi /volume1/tftpboot/grubx64.efi
elif [ -f $MOUNT_POINT/EFI/BOOT/BOOTX64.EFI ]; then
  sudo cp $MOUNT_POINT/EFI/BOOT/BOOTX64.EFI /volume1/tftpboot/grubx64.efi
fi

# Cleanup
sudo umount $MOUNT_POINT 2>/dev/null || true
sudo rm -rf $MOUNT_POINT /tmp/initrd-work

# 8. Start TFTP service
echo "[8/8] Starting TFTP service..."
sudo pkill opentftp 2>/dev/null || true
sleep 1
sudo /usr/bin/opentftp -i /etc/opentftp.ini -l /var/log/opentftp.log &

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Verifying files:"
ls -lh /volume1/tftpboot/
echo ""
ls -lh /volume1/tftpboot/proxmox/
echo ""
ls -lh /volume1/tftpboot/grub/
echo ""
echo "TFTP processes:"
ps aux | grep opentftp | grep -v grep || echo "No TFTP running"
echo ""
echo "Next steps:"
echo "1. Configure DHCP options 66/67 in DSM:"
echo "   Control Panel -> Network -> DHCP Server"
echo "   Option 66: 192.168.50.215"
echo "   Option 67: grubx64.efi"
echo ""
echo "2. Boot target PC via PXE"
echo ""
