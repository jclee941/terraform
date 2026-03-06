# Proxmox LXC Module

Provisions LXC containers on Proxmox VE via the `bpg/proxmox` provider.
Handles CPU, memory, storage, and network configuration with input validation
for VMID ranges, memory minimums, and hostname format.

<!-- BEGIN_TF_DOCS -->


## Requirements

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7, < 2.0 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | ~> 0.94 |

## Providers

## Providers

| Name | Version |
|------|---------|
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | 0.95.0 |

## Resources

## Resources

| Name | Type |
|------|------|
| [proxmox_virtual_environment_container.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_container) | resource |
| [proxmox_virtual_environment_nodes.nodes](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/data-sources/virtual_environment_nodes) | data source |

## Inputs

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cores"></a> [cores](#input\_cores) | CPU cores | `number` | n/a | yes |
| <a name="input_datastore_id"></a> [datastore\_id](#input\_datastore\_id) | Proxmox storage ID for container disks | `string` | n/a | yes |
| <a name="input_description"></a> [description](#input\_description) | Container description | `string` | n/a | yes |
| <a name="input_disk_size"></a> [disk\_size](#input\_disk\_size) | Disk size in GB | `number` | n/a | yes |
| <a name="input_dns_servers"></a> [dns\_servers](#input\_dns\_servers) | DNS servers for containers | `list(string)` | n/a | yes |
| <a name="input_hostname"></a> [hostname](#input\_hostname) | Container hostname | `string` | n/a | yes |
| <a name="input_ip_address"></a> [ip\_address](#input\_ip\_address) | Container IPv4 address (without CIDR) | `string` | n/a | yes |
| <a name="input_managed_vmid_max"></a> [managed\_vmid\_max](#input\_managed\_vmid\_max) | Maximum managed VMID | `number` | n/a | yes |
| <a name="input_managed_vmid_min"></a> [managed\_vmid\_min](#input\_managed\_vmid\_min) | Minimum managed VMID | `number` | n/a | yes |
| <a name="input_memory"></a> [memory](#input\_memory) | Dedicated memory in MB | `number` | n/a | yes |
| <a name="input_network_gateway"></a> [network\_gateway](#input\_network\_gateway) | Network gateway IP address | `string` | n/a | yes |
| <a name="input_node_name"></a> [node\_name](#input\_node\_name) | Proxmox node name to deploy the container | `string` | n/a | yes |
| <a name="input_vmid"></a> [vmid](#input\_vmid) | Container VMID | `number` | n/a | yes |
| <a name="input_privileged"></a> [privileged](#input\_privileged) | Run container in privileged mode | `bool` | `false` | no |
| <a name="input_ssh_public_keys"></a> [ssh\_public\_keys](#input\_ssh\_public\_keys) | SSH public keys for root user | `list(string)` | `[]` | no |
| <a name="input_swap"></a> [swap](#input\_swap) | Swap memory in MB (per-container) | `number` | `512` | no |
| <a name="input_template_file_id"></a> [template\_file\_id](#input\_template\_file\_id) | Container template file ID (e.g., local:vztmpl/debian-12-standard\_12.12-1\_amd64.tar.zst) | `string` | `"local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst"` | no |

## Outputs

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ip_address"></a> [ip\_address](#output\_ip\_address) | Container IP address |
| <a name="output_status"></a> [status](#output\_status) | Container status summary |
| <a name="output_vmid"></a> [vmid](#output\_vmid) | Container VMID |

<!-- END_TF_DOCS -->
