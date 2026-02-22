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

Set `OP_SERVICE_ACCOUNT_TOKEN` as an environment variable or pass it via
the provider configuration in the consuming workspace.

<!-- BEGIN_TF_DOCS -->

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7, < 2.0 |
| <a name="requirement_onepassword"></a> [onepassword](#requirement\_onepassword) | ~> 3.2 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_onepassword"></a> [onepassword](#provider\_onepassword) | ~> 3.2 |

## Resources

| Name | Type |
|------|------|
| [onepassword_item.archon](https://registry.terraform.io/providers/1Password/onepassword/latest/docs/data-sources/item) | data source |
| [onepassword_item.cloudflare](https://registry.terraform.io/providers/1Password/onepassword/latest/docs/data-sources/item) | data source |
| [onepassword_item.elk](https://registry.terraform.io/providers/1Password/onepassword/latest/docs/data-sources/item) | data source |
| [onepassword_item.exa](https://registry.terraform.io/providers/1Password/onepassword/latest/docs/data-sources/item) | data source |
| [onepassword_item.github](https://registry.terraform.io/providers/1Password/onepassword/latest/docs/data-sources/item) | data source |
| [onepassword_item.glitchtip](https://registry.terraform.io/providers/1Password/onepassword/latest/docs/data-sources/item) | data source |
| [onepassword_item.grafana](https://registry.terraform.io/providers/1Password/onepassword/latest/docs/data-sources/item) | data source |
| [onepassword_item.mcphub](https://registry.terraform.io/providers/1Password/onepassword/latest/docs/data-sources/item) | data source |
| [onepassword_item.n8n](https://registry.terraform.io/providers/1Password/onepassword/latest/docs/data-sources/item) | data source |
| [onepassword_item.proxmox](https://registry.terraform.io/providers/1Password/onepassword/latest/docs/data-sources/item) | data source |
| [onepassword_item.splunk](https://registry.terraform.io/providers/1Password/onepassword/latest/docs/data-sources/item) | data source |
| [onepassword_item.supabase](https://registry.terraform.io/providers/1Password/onepassword/latest/docs/data-sources/item) | data source |
| [onepassword_vault.this](https://registry.terraform.io/providers/1Password/onepassword/latest/docs/data-sources/vault) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_vault_name"></a> [vault\_name](#input\_vault\_name) | 1Password vault name containing homelab secrets | `string` | `"homelab"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_secrets"></a> [secrets](#output\_secrets) | Flat map of all homelab secrets for template\_vars merge (31 keys) |
| <a name="output_metadata"></a> [metadata](#output\_metadata) | Non-secret configuration metadata: usernames, URLs, IDs (8 keys) |

<!-- END_TF_DOCS -->
