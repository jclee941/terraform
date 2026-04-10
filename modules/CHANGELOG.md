# Module Changelog

All module tags follow `modules/<path>/v<semver>` and are released from the monorepo root.

## modules/proxmox/lxc/v1.0.0
- Initial release.
- Provisions Proxmox LXC containers with lifecycle and network configuration.

## modules/proxmox/vm/v1.0.0
- Initial release.
- Provisions Proxmox QEMU VMs with clone/cloud-init support.

## modules/proxmox/lxc-config/v1.0.0
- Initial release.
- Deploys and manages LXC guest configuration artifacts over SSH.

## modules/proxmox/vm-config/v1.0.0
- Initial release.
- Deploys and manages VM guest configuration artifacts over SSH.

## modules/proxmox/config-renderer/v1.0.0
- Initial release.
- Renders service templates into workspace-managed config outputs.

## modules/shared/onepassword-secrets/v1.0.0
- Initial release.
- Loads shared secrets/metadata from 1Password for Terraform consumers.
