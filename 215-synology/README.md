# 215-synology: Synology NAS

## Overview

Synology NAS providing network-attached storage for the homelab. Managed via the `synology-community/synology` Terraform provider for DSM packages, Docker Compose projects, and file operations.

## Architecture

#### Diagram summary 1

- Type: flowchart
- Internet -> Cloudflare Tunnel (Cloudflare)
- Cloudflare Tunnel (cloudflared-homelab on cliproxy/114) -> Synology DSM\n192.168.50.215:5001 (DSM)
- Synology DSM\n192.168.50.215 (DSM) -> Container Manager (Services)


## Source of Truth

- **Host inventory**: `100-pve/envs/prod/hosts.tf` → `hosts.synology`
- **Terraform resources**: `main.tf`, `variables.tf`, `onepassword.tf`
- **Cloudflare direct route**: `300-cloudflare/` -> `https://192.168.50.215:5001`

## Operations

```bash
make plan SVC=synology    # Plan changes
# Apply via CI only (merge to main/master)
```

## Safety Notes

- This is a **physical device**, not a Proxmox VM/LXC.
- Provider requires DSM 7.0+ with HTTPS enabled on port 5001.
- `skip_cert_check = true` is set for self-signed DSM certificates.
- Do not hardcode IPs in service configs. Use `module.hosts.synology_ip`.
- DSM admin credentials are stored in 1Password vault "homelab" under item "synology".

## MailPlus Recovery Notes

- `mailplus_domain_id` defaults to `1` because the live primary `jclee.me` domain was verified as ID 1. Before changing or applying it in another environment, verify the value with `SYNO.MailPlusServer.Domain/list`.
- MailPlus Server routing and IMAPS work independently of the optional MailClient package. Stable MailClient `4.0.1-22254` currently fails the official compatibility preinstall check against MailPlus Server `4.0.2-31664`; do not downgrade, install a beta, patch the SPK, or bypass the guard. Wait for a compatible stable client.
- Verify recovery with an API catch-all read-back, a fresh random SMTP recipient that receives `RCPT TO` `250`, and an IMAPS login.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7, < 2.0 |
| <a name="requirement_onepassword"></a> [onepassword](#requirement\_onepassword) | ~> 3.2 |
| <a name="requirement_synology"></a> [synology](#requirement\_synology) | ~> 0.6 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_synology"></a> [synology](#provider\_synology) | 0.6.9 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_onepassword_secrets"></a> [onepassword\_secrets](#module\_onepassword\_secrets) | ../modules/shared/onepassword-secrets | n/a |

## Resources

| Name | Type |
|------|------|
| [synology_api.mailplus_catch_all](https://registry.terraform.io/providers/synology-community/synology/latest/docs/resources/api) | resource |
| [synology_container_project.proxmox_monitor](https://registry.terraform.io/providers/synology-community/synology/latest/docs/resources/container_project) | resource |
| [synology_core_package.container_manager](https://registry.terraform.io/providers/synology-community/synology/latest/docs/resources/core_package) | resource |
| [synology_core_network.this](https://registry.terraform.io/providers/synology-community/synology/latest/docs/data-sources/core_network) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_enable_container_manager_package"></a> [enable\_container\_manager\_package](#input\_enable\_container\_manager\_package) | Manage ContainerManager package installation via Terraform | `bool` | `false` | no |
| <a name="input_enable_mailplus_catch_all"></a> [enable\_mailplus\_catch\_all](#input\_enable\_mailplus\_catch\_all) | Route otherwise-unmatched addresses in the primary MailPlus domain to one DSM user | `bool` | `true` | no |
| <a name="input_enable_portainer"></a> [enable\_portainer](#input\_enable\_portainer) | Enable Portainer CE container deployment on Synology | `bool` | `false` | no |
| <a name="input_enable_proxmox_monitor"></a> [enable\_proxmox\_monitor](#input\_enable\_proxmox\_monitor) | Run the Proxmox resource monitor independently on Synology Container Manager | `bool` | `true` | no |
| <a name="input_mailplus_catch_all_user"></a> [mailplus\_catch\_all\_user](#input\_mailplus\_catch\_all\_user) | DSM user that receives otherwise-unmatched mail for the primary MailPlus domain | `string` | `"jclee"` | no |
| <a name="input_mailplus_domain_id"></a> [mailplus\_domain\_id](#input\_mailplus\_domain\_id) | MailPlus primary domain identifier returned by SYNO.MailPlusServer.Domain/list | `number` | `1` | no |
| <a name="input_onepassword_vault_name"></a> [onepassword\_vault\_name](#input\_onepassword\_vault\_name) | 1Password vault name for secret retrieval | `string` | `"homelab"` | no |
| <a name="input_portainer_edge_port"></a> [portainer\_edge\_port](#input\_portainer\_edge\_port) | Published TCP port for Portainer Edge agent communication | `string` | `"8000"` | no |
| <a name="input_portainer_https_port"></a> [portainer\_https\_port](#input\_portainer\_https\_port) | Published HTTPS port for Portainer web UI | `string` | `"9443"` | no |
| <a name="input_proxmox_monitor_cpu_percent"></a> [proxmox\_monitor\_cpu\_percent](#input\_proxmox\_monitor\_cpu\_percent) | CPU usage percentage that triggers a sustained pressure alert | `number` | `95` | no |
| <a name="input_proxmox_monitor_disk_percent"></a> [proxmox\_monitor\_disk\_percent](#input\_proxmox\_monitor\_disk\_percent) | Disk usage percentage that triggers a sustained pressure alert | `number` | `90` | no |
| <a name="input_proxmox_monitor_failure_threshold"></a> [proxmox\_monitor\_failure\_threshold](#input\_proxmox\_monitor\_failure\_threshold) | Consecutive unhealthy polls required before sending a Telegram alert | `number` | `3` | no |
| <a name="input_proxmox_monitor_image"></a> [proxmox\_monitor\_image](#input\_proxmox\_monitor\_image) | Pinned Go runtime image used to build and run the mounted Proxmox monitor source | `string` | `"golang:1.25.0-alpine3.22"` | no |
| <a name="input_proxmox_monitor_interval"></a> [proxmox\_monitor\_interval](#input\_proxmox\_monitor\_interval) | Polling interval passed to the Proxmox monitor | `string` | `"60s"` | no |
| <a name="input_proxmox_monitor_memory_percent"></a> [proxmox\_monitor\_memory\_percent](#input\_proxmox\_monitor\_memory\_percent) | Memory usage percentage that triggers a sustained pressure alert | `number` | `95` | no |
| <a name="input_synology_host"></a> [synology\_host](#input\_synology\_host) | Synology DSM HTTPS URL (e.g. https://192.168.50.215:5001) | `string` | `"https://192.168.50.215:5001"` | no |
| <a name="input_synology_password"></a> [synology\_password](#input\_synology\_password) | Synology DSM admin password (overridden by 1Password if available) | `string` | `""` | no |
| <a name="input_synology_skip_cert_check"></a> [synology\_skip\_cert\_check](#input\_synology\_skip\_cert\_check) | Skip TLS certificate verification for self-signed DSM certs | `bool` | `true` | no |
| <a name="input_synology_user"></a> [synology\_user](#input\_synology\_user) | Synology DSM admin username (overridden by 1Password if available) | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_container_manager_installed"></a> [container\_manager\_installed](#output\_container\_manager\_installed) | Whether ContainerManager package is installed |
| <a name="output_mailplus_catch_all"></a> [mailplus\_catch\_all](#output\_mailplus\_catch\_all) | Configured MailPlus catch-all target for the primary domain |
| <a name="output_network_info"></a> [network\_info](#output\_network\_info) | Synology NAS network configuration |
| <a name="output_portainer_enabled"></a> [portainer\_enabled](#output\_portainer\_enabled) | Whether Portainer container project is enabled |
| <a name="output_portainer_endpoints"></a> [portainer\_endpoints](#output\_portainer\_endpoints) | Portainer endpoint details when container project is enabled |
| <a name="output_proxmox_monitor_status"></a> [proxmox\_monitor\_status](#output\_proxmox\_monitor\_status) | Synology Container Manager project status for the Proxmox Telegram monitor |
<!-- END_TF_DOCS -->
