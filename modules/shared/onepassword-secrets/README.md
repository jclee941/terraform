# 1Password Secrets Module

Retrieves secrets from 1Password at plan time via the
[1Password Terraform provider](https://registry.terraform.io/providers/1Password/onepassword/latest).
Drop-in replacement for `modules/shared/vault-secrets` with an identical
`secrets` and `metadata` output maps.

## 1Password Item Structure

Each item in the vault must contain a section named **"secrets"** with fields
matching the original Vault KV key names:

```
Item: "grafana"  (category: password)
  +-- Section: "secrets"
      |-- Field: "admin_password"        (CONCEALED)
      +-- Field: "service_account_token" (CONCEALED)
```

## Authentication

Set `OP_CONNECT_TOKEN` and `OP_CONNECT_HOST` as environment variables (Connect Server on LXC 112 at `http://192.168.50.112:8090`) or pass them via the provider configuration in the consuming workspace. The provider falls back to these when `op_service_account_token` variable is empty.

<!-- BEGIN_TF_DOCS -->


## Requirements

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7, < 2.0 |
| <a name="requirement_onepassword"></a> [onepassword](#requirement\_onepassword) | ~> 3.2 |

## Providers

## Providers

| Name | Version |
|------|---------|
| <a name="provider_onepassword"></a> [onepassword](#provider\_onepassword) | 3.2.1 |

## Resources

## Resources

| Name | Type |
|------|------|
| [onepassword_item.this](https://registry.terraform.io/providers/1Password/onepassword/latest/docs/data-sources/item) | data source |
| [onepassword_vault.this](https://registry.terraform.io/providers/1Password/onepassword/latest/docs/data-sources/vault) | data source |

## Inputs

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_enable_gcp"></a> [enable\_gcp](#input\_enable\_gcp) | Whether to look up GCP secrets from 1Password (requires 'gcp' item in vault) | `bool` | `false` | no |
| <a name="input_enable_pbs"></a> [enable\_pbs](#input\_enable\_pbs) | Whether to look up PBS secrets from 1Password (requires 'pbs' item in vault) | `bool` | `false` | no |
| <a name="input_enable_synology"></a> [enable\_synology](#input\_enable\_synology) | Whether to look up Synology secrets from 1Password (requires 'synology' item in vault) | `bool` | `false` | no |
| <a name="input_enable_youtube"></a> [enable\_youtube](#input\_enable\_youtube) | Whether to look up YouTube secrets from 1Password (requires 'youtube' item in vault) | `bool` | `false` | no |
| <a name="input_vault_name"></a> [vault\_name](#input\_vault\_name) | 1Password vault name containing homelab secrets | `string` | `"homelab"` | no |

## Outputs

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_metadata"></a> [metadata](#output\_metadata) | Non-secret configuration metadata: usernames, URLs, IDs (15 keys) |
| <a name="output_secrets"></a> [secrets](#output\_secrets) | Flat map of all homelab secrets for template\_vars merge (43 keys) |

<!-- END_TF_DOCS -->
