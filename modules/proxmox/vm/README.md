# Proxmox VM Module

Provisions QEMU/KVM virtual machines on Proxmox VE via the `bpg/proxmox`
provider. Supports cloud-init, PCI passthrough, and clone-based deployments
with validation for VMID, memory alignment, BIOS type, and disk interface.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7, < 2.0 |

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
| <a name="input_bios"></a> [bios](#input\_bios) | BIOS type (seabios or ovmf) | `string` | `"seabios"` | no |
| <a name="input_clone_template_id"></a> [clone\_template\_id](#input\_clone\_template\_id) | Template VMID to clone from | `number` | `9000` | no |
| <a name="input_cloud_init_datastore_id"></a> [cloud\_init\_datastore\_id](#input\_cloud\_init\_datastore\_id) | Datastore for cloud-init drive | `string` | `"local"` | no |
| <a name="input_cloud_init_file_id"></a> [cloud\_init\_file\_id](#input\_cloud\_init\_file\_id) | Cloud-init user-data snippet file ID | `string` | `null` | no |
| <a name="input_cores"></a> [cores](#input\_cores) | CPU cores | `number` | n/a | yes |
| <a name="input_cpu_type"></a> [cpu\_type](#input\_cpu\_type) | CPU type | `string` | `"host"` | no |
| <a name="input_datastore_id"></a> [datastore\_id](#input\_datastore\_id) | Proxmox storage ID for VM disks | `string` | n/a | yes |
| <a name="input_description"></a> [description](#input\_description) | VM description | `string` | n/a | yes |
| <a name="input_disk_interface"></a> [disk\_interface](#input\_disk\_interface) | Disk interface (scsi0, virtio0, etc.) | `string` | `"scsi0"` | no |
| <a name="input_disk_size"></a> [disk\_size](#input\_disk\_size) | Disk size in GB | `number` | n/a | yes |
| <a name="input_dns_servers"></a> [dns\_servers](#input\_dns\_servers) | DNS servers | `list(string)` | n/a | yes |
| <a name="input_hostname"></a> [hostname](#input\_hostname) | VM hostname | `string` | n/a | yes |
| <a name="input_ip_address"></a> [ip\_address](#input\_ip\_address) | VM IPv4 address (without CIDR) | `string` | n/a | yes |
| <a name="input_machine"></a> [machine](#input\_machine) | Machine type (pc or q35) | `string` | `"pc"` | no |
| <a name="input_managed_vmid_max"></a> [managed\_vmid\_max](#input\_managed\_vmid\_max) | Maximum managed VMID | `number` | n/a | yes |
| <a name="input_managed_vmid_min"></a> [managed\_vmid\_min](#input\_managed\_vmid\_min) | Minimum managed VMID | `number` | n/a | yes |
| <a name="input_memory"></a> [memory](#input\_memory) | Dedicated memory in MB | `number` | n/a | yes |
| <a name="input_network_gateway"></a> [network\_gateway](#input\_network\_gateway) | Network gateway IP | `string` | n/a | yes |
| <a name="input_node_name"></a> [node\_name](#input\_node\_name) | Proxmox node name | `string` | n/a | yes |
| <a name="input_on_boot"></a> [on\_boot](#input\_on\_boot) | Start VM on host boot | `bool` | `true` | no |
| <a name="input_vmid"></a> [vmid](#input\_vmid) | VM ID | `number` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ip_address"></a> [ip\_address](#output\_ip\_address) | VM IP address |
| <a name="output_status"></a> [status](#output\_status) | VM status summary |
| <a name="output_vmid"></a> [vmid](#output\_vmid) | VM ID |
<!-- END_TF_DOCS -->
