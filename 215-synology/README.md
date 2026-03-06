# 215-synology

Synology NAS — network-attached storage for the homelab, managed via Terraform.

- **IP**: `192.168.50.215`
- **DSM**: Port 5001 (HTTPS API), Port 5000 (HTTP proxied via Traefik at `nas.jclee.me`)
- **Roles**: NAS, Storage
- **Provider**: `synology-community/synology` ~>0.6

## Terraform Resources

| Resource | Purpose |
|----------|---------|
| `synology_core_package.container_manager` | Ensure ContainerManager package is installed |
| `data.synology_core_network.this` | Read NAS network configuration |

## Integration

This device is referenced as a host in `100-pve/envs/prod/hosts.tf` and consumed by:
- **Traefik** (`102-traefik/templates/synology.yml.tftpl`) for reverse proxy routing
- **Cloudflare** (`300-cloudflare/`) for tunnel connectivity
- **ELK** (`105-elk/`) for syslog ingestion

## Credentials

DSM admin credentials are stored in 1Password vault "homelab" under item "synology" with fields:
- `secrets.user` — DSM admin username
- `secrets.password` — DSM admin password

## Usage

```bash
make plan SVC=synology    # Plan changes
# Apply via CI only (merge to master)
```

## Notes

- Physical device, not a Proxmox VM/LXC
- Provider requires DSM 7.0+ with HTTPS enabled on port 5001
- `skip_cert_check = true` for self-signed DSM certificates
- IP and port information flows through `module.hosts` → dependent workspaces

<!-- BEGIN_TF_DOCS -->


## Requirements

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7, < 2.0 |
| <a name="requirement_onepassword"></a> [onepassword](#requirement\_onepassword) | ~> 3.2 |
| <a name="requirement_synology"></a> [synology](#requirement\_synology) | ~> 0.6 |

## Providers

## Providers

| Name | Version |
|------|---------|
| <a name="provider_synology"></a> [synology](#provider\_synology) | 0.6.9 |

## Resources

## Resources

| Name | Type |
|------|------|
| [synology_core_package.container_manager](https://registry.terraform.io/providers/synology-community/synology/latest/docs/resources/core_package) | resource |
| [synology_core_network.this](https://registry.terraform.io/providers/synology-community/synology/latest/docs/data-sources/core_network) | data source |

## Inputs

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_onepassword_vault_name"></a> [onepassword\_vault\_name](#input\_onepassword\_vault\_name) | 1Password vault name for secret retrieval | `string` | `"homelab"` | no |
| <a name="input_synology_host"></a> [synology\_host](#input\_synology\_host) | Synology DSM HTTPS URL (e.g. https://192.168.50.215:5001) | `string` | `"https://192.168.50.215:5001"` | no |
| <a name="input_synology_password"></a> [synology\_password](#input\_synology\_password) | Synology DSM admin password (overridden by 1Password if available) | `string` | `""` | no |
| <a name="input_synology_skip_cert_check"></a> [synology\_skip\_cert\_check](#input\_synology\_skip\_cert\_check) | Skip TLS certificate verification for self-signed DSM certs | `bool` | `true` | no |
| <a name="input_synology_user"></a> [synology\_user](#input\_synology\_user) | Synology DSM admin username (overridden by 1Password if available) | `string` | `""` | no |

## Outputs

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_container_manager_installed"></a> [container\_manager\_installed](#output\_container\_manager\_installed) | Whether ContainerManager package is installed |
| <a name="output_network_info"></a> [network\_info](#output\_network\_info) | Synology NAS network configuration |

<!-- END_TF_DOCS -->