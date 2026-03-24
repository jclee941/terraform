# 1Password Secrets Module

Retrieves secrets from 1Password at plan time via the
[1Password Terraform provider](https://registry.terraform.io/providers/1Password/onepassword/latest).
The module exposes three output maps:

- `secrets` — sensitive API keys, passwords, and tokens
- `metadata` — stable non-secret metadata kept for backward compatibility
- `connection_info` — endpoints, URLs, usernames, IDs, and related connection fields

## 1Password Item Structure

Preferred item structure uses semantic section names with spaces:
**Credentials**, **API Keys**, **Connection**, **Database**, **Dashboard**,
**Account**, **MCP Tokens**, **OpenCode Tokens**, **Keys**, **Login**, **OAuth**, **Passwords**, and **Secrets**.

```
Item: "grafana"  (category: password)
  +-- Section: "Credentials"
      |-- Field: "admin_password"        (CONCEALED)
      +-- Field: "service_account_token" (CONCEALED)
```

For API_CREDENTIAL items such as `github`, the module also supports top-level
`.credential` fallback during migration.

## Authentication

Set `OP_SERVICE_ACCOUNT_TOKEN` as an environment variable for Terraform and CLI verification flows. The repo's current Terraform provider usage is environment-driven, with empty `provider "onepassword" {}` blocks in consuming workspaces. `OP_CONNECT_TOKEN` and `OP_CONNECT_HOST` remain relevant for MCPHub-side Connect integrations, not the Terraform provider path.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7, < 2.0 |
| <a name="requirement_onepassword"></a> [onepassword](#requirement\_onepassword) | ~> 3.2 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_onepassword"></a> [onepassword](#provider\_onepassword) | 3.2.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [onepassword_item.this](https://registry.terraform.io/providers/1Password/onepassword/latest/docs/data-sources/item) | data source |
| [onepassword_vault.this](https://registry.terraform.io/providers/1Password/onepassword/latest/docs/data-sources/vault) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_enable_gcp"></a> [enable\_gcp](#input\_enable\_gcp) | Whether to look up GCP secrets from 1Password (requires 'gcp' item in vault) | `bool` | `false` | no |
| <a name="input_enable_pbs"></a> [enable\_pbs](#input\_enable\_pbs) | Whether to look up PBS secrets from 1Password (requires 'pbs' item in vault) | `bool` | `false` | no |
| <a name="input_enable_synology"></a> [enable\_synology](#input\_enable\_synology) | Whether to look up Synology secrets from 1Password (requires 'synology' item in vault) | `bool` | `false` | no |
| <a name="input_enable_youtube"></a> [enable\_youtube](#input\_enable\_youtube) | Whether to look up YouTube secrets from 1Password (requires 'youtube' item in vault) | `bool` | `false` | no |
| <a name="input_vault_name"></a> [vault\_name](#input\_vault\_name) | 1Password vault name containing homelab secrets | `string` | `"homelab"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_connection_info"></a> [connection\_info](#output\_connection\_info) | Non-secret connection details and routing metadata (16 keys) |
| <a name="output_metadata"></a> [metadata](#output\_metadata) | Non-secret configuration metadata: usernames, URLs, IDs (14 keys) |
| <a name="output_secrets"></a> [secrets](#output\_secrets) | Flat map of all homelab secrets for template\_vars merge (37 keys) |
<!-- END_TF_DOCS -->
