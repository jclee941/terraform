# Proxmox VM Module

Provisions QEMU/KVM virtual machines on Proxmox VE via the `bpg/proxmox`
provider. Supports cloud-init, PCI passthrough, and clone-based deployments
with validation for VMID, memory alignment, BIOS type, and disk interface.

## Architecture

#### Diagram summary 1

- Type: flowchart
- Input variables (Inputs) -> Terraform module (Module)
- Terraform module (Module) -> Managed resources or rendered templates (Resources)
- Managed resources or rendered templates (Resources) -> Output values (Outputs)
- Output values (Outputs) -> Workspace consumers (Consumers)


<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7, < 2.0 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | ~> 0.94 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | 0.97.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [proxmox_virtual_environment_vm.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm) | resource |
| [proxmox_virtual_environment_nodes.nodes](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/data-sources/virtual_environment_nodes) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_balloon_min"></a> [balloon\_min](#input\_balloon\_min) | Balloon minimum memory in MB (0 = balloon disabled) | `number` | `0` | no |
| <a name="input_bios"></a> [bios](#input\_bios) | BIOS type (seabios or ovmf) | `string` | `"seabios"` | no |
| <a name="input_clone_template_id"></a> [clone\_template\_id](#input\_clone\_template\_id) | Template VMID to clone from | `number` | `9000` | no |
| <a name="input_cloud_init_datastore_id"></a> [cloud\_init\_datastore\_id](#input\_cloud\_init\_datastore\_id) | Datastore for cloud-init drive | `string` | `"local"` | no |
| <a name="input_cloud_init_file_id"></a> [cloud\_init\_file\_id](#input\_cloud\_init\_file\_id) | Cloud-init user-data snippet file ID | `string` | `null` | no |
| <a name="input_cores"></a> [cores](#input\_cores) | CPU cores | `number` | n/a | yes |
| <a name="input_cpu_limit"></a> [cpu\_limit](#input\_cpu\_limit) | CPU usage limit in cores (null = Proxmox default/no explicit limit) | `number` | `null` | no |
| <a name="input_cpu_numa"></a> [cpu\_numa](#input\_cpu\_numa) | Enable NUMA CPU topology | `bool` | `false` | no |
| <a name="input_cpu_type"></a> [cpu\_type](#input\_cpu\_type) | CPU type | `string` | `"host"` | no |
| <a name="input_cpu_units"></a> [cpu\_units](#input\_cpu\_units) | CPU scheduler weight (null = Proxmox default) | `number` | `null` | no |
| <a name="input_datastore_id"></a> [datastore\_id](#input\_datastore\_id) | Proxmox storage ID for VM disks | `string` | n/a | yes |
| <a name="input_description"></a> [description](#input\_description) | VM description | `string` | n/a | yes |
| <a name="input_disk_aio"></a> [disk\_aio](#input\_disk\_aio) | Disk async IO mode (io\_uring, native, or threads) | `string` | `"io_uring"` | no |
| <a name="input_disk_backup"></a> [disk\_backup](#input\_disk\_backup) | Include VM disk in Proxmox backups (null = provider default) | `bool` | `null` | no |
| <a name="input_disk_cache"></a> [disk\_cache](#input\_disk\_cache) | Disk cache mode (null = provider default) | `string` | `null` | no |
| <a name="input_disk_discard"></a> [disk\_discard](#input\_disk\_discard) | Disk discard mode (on or ignore) | `string` | `"on"` | no |
| <a name="input_disk_interface"></a> [disk\_interface](#input\_disk\_interface) | Disk interface (scsi0, virtio0, etc.) | `string` | `"scsi0"` | no |
| <a name="input_disk_replicate"></a> [disk\_replicate](#input\_disk\_replicate) | Include VM disk in replication jobs (null = provider default) | `bool` | `null` | no |
| <a name="input_disk_size"></a> [disk\_size](#input\_disk\_size) | Disk size in GB | `number` | n/a | yes |
| <a name="input_dns_servers"></a> [dns\_servers](#input\_dns\_servers) | DNS servers | `list(string)` | n/a | yes |
| <a name="input_efi_pre_enrolled_keys"></a> [efi\_pre\_enrolled\_keys](#input\_efi\_pre\_enrolled\_keys) | Use pre-enrolled EFI secure boot keys for OVMF VMs | `bool` | `false` | no |
| <a name="input_hostname"></a> [hostname](#input\_hostname) | VM hostname | `string` | n/a | yes |
| <a name="input_hostpci_devices"></a> [hostpci\_devices](#input\_hostpci\_devices) | PCI devices to pass through to the VM (use 'mapping' for resource-mapped devices, 'id' for raw passthrough) | <pre>list(object({<br/>    device   = string<br/>    mapping  = optional(string)<br/>    id       = optional(string)<br/>    mdev     = optional(string)<br/>    pcie     = optional(bool, true)<br/>    rom_file = optional(string)<br/>    rombar   = optional(bool)<br/>    xvga     = optional(bool)<br/>  }))</pre> | `[]` | no |
| <a name="input_hotplug"></a> [hotplug](#input\_hotplug) | VM hotplug feature list, or 0 to disable | `string` | `null` | no |
| <a name="input_ip_address"></a> [ip\_address](#input\_ip\_address) | VM IPv4 address (without CIDR) | `string` | n/a | yes |
| <a name="input_keyboard_layout"></a> [keyboard\_layout](#input\_keyboard\_layout) | VM keyboard layout (null = provider default) | `string` | `null` | no |
| <a name="input_machine"></a> [machine](#input\_machine) | Machine type (pc or q35) | `string` | `"pc"` | no |
| <a name="input_managed_vmid_max"></a> [managed\_vmid\_max](#input\_managed\_vmid\_max) | Maximum managed VMID | `number` | n/a | yes |
| <a name="input_managed_vmid_min"></a> [managed\_vmid\_min](#input\_managed\_vmid\_min) | Minimum managed VMID | `number` | n/a | yes |
| <a name="input_memory"></a> [memory](#input\_memory) | Dedicated memory in MB | `number` | n/a | yes |
| <a name="input_network_gateway"></a> [network\_gateway](#input\_network\_gateway) | Network gateway IP | `string` | n/a | yes |
| <a name="input_node_name"></a> [node\_name](#input\_node\_name) | Proxmox node name | `string` | n/a | yes |
| <a name="input_on_boot"></a> [on\_boot](#input\_on\_boot) | Start VM on host boot | `bool` | `true` | no |
| <a name="input_protection"></a> [protection](#input\_protection) | Protect VM and disks from removal | `bool` | `true` | no |
| <a name="input_qemu_agent_trim"></a> [qemu\_agent\_trim](#input\_qemu\_agent\_trim) | Enable fstrim on cloned disks via QEMU agent | `bool` | `true` | no |
| <a name="input_qemu_agent_type"></a> [qemu\_agent\_type](#input\_qemu\_agent\_type) | QEMU agent interface type | `string` | `"virtio"` | no |
| <a name="input_scsi_hardware"></a> [scsi\_hardware](#input\_scsi\_hardware) | SCSI controller model | `string` | `"virtio-scsi-single"` | no |
| <a name="input_serial_devices"></a> [serial\_devices](#input\_serial\_devices) | Serial devices to attach to the VM | <pre>list(object({<br/>    device = optional(string, "socket")<br/>  }))</pre> | `[]` | no |
| <a name="input_ssd_emulation"></a> [ssd\_emulation](#input\_ssd\_emulation) | Enable SSD emulation (TRIM support via guest OS) | `bool` | `true` | no |
| <a name="input_started"></a> [started](#input\_started) | Keep VM started | `bool` | `true` | no |
| <a name="input_tablet_device"></a> [tablet\_device](#input\_tablet\_device) | Enable USB tablet device | `bool` | `false` | no |
| <a name="input_usb_devices"></a> [usb\_devices](#input\_usb\_devices) | USB devices to pass through to the VM | <pre>list(object({<br/>    host = string<br/>    usb3 = optional(bool, false)<br/>  }))</pre> | `[]` | no |
| <a name="input_vga_clipboard"></a> [vga\_clipboard](#input\_vga\_clipboard) | VGA clipboard mode (null = disabled/provider default) | `string` | `null` | no |
| <a name="input_vga_memory"></a> [vga\_memory](#input\_vga\_memory) | VGA memory in MB (null = provider default) | `number` | `16` | no |
| <a name="input_vga_type"></a> [vga\_type](#input\_vga\_type) | VGA type | `string` | `"std"` | no |
| <a name="input_vmid"></a> [vmid](#input\_vmid) | VM ID | `number` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ip_address"></a> [ip\_address](#output\_ip\_address) | VM IP address |
| <a name="output_status"></a> [status](#output\_status) | VM status summary |
| <a name="output_vmid"></a> [vmid](#output\_vmid) | VM ID |
<!-- END_TF_DOCS -->
