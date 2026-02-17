# Vault Agent Module

Configures HashiCorp Vault Agent with AppRole auto-auth for runtime
secret injection. Generates agent config, template files, and systemd
unit for automatic token renewal and secret rendering.

<!-- BEGIN_TF_DOCS -->


## Requirements

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7, < 2.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | ~> 2.0 |
| <a name="requirement_vault"></a> [vault](#requirement\_vault) | ~> 5.0 |

## Providers

## Providers

| Name | Version |
|------|---------|
| <a name="provider_vault"></a> [vault](#provider\_vault) | 4.8.0 |

## Resources

## Resources

| Name | Type |
|------|------|
| [vault_approle_auth_backend_role.service](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/approle_auth_backend_role) | resource |
| [vault_approle_auth_backend_role_secret_id.service](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/approle_auth_backend_role_secret_id) | resource |
| [vault_auth_backend.approle](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/auth_backend) | resource |
| [vault_policy.service](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/policy) | resource |

## Inputs

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_kv_path"></a> [kv\_path](#input\_kv\_path) | KV secret path under the mount (e.g. homelab/mcphub) | `string` | n/a | yes |
| <a name="input_service_name"></a> [service\_name](#input\_service\_name) | Service identifier used for Vault role and policy naming | `string` | n/a | yes |
| <a name="input_additional_kv_paths"></a> [additional\_kv\_paths](#input\_additional\_kv\_paths) | Additional KV secret paths this agent needs read access to | `list(string)` | `[]` | no |
| <a name="input_approle_backend_path"></a> [approle\_backend\_path](#input\_approle\_backend\_path) | Path of the AppRole auth backend | `string` | `"approle"` | no |
| <a name="input_create_approle_backend"></a> [create\_approle\_backend](#input\_create\_approle\_backend) | Whether to create the AppRole auth backend (set false if it already exists) | `bool` | `false` | no |
| <a name="input_template_mappings"></a> [template\_mappings](#input\_template\_mappings) | Map of Vault Agent template source to destination paths | <pre>map(object({<br/>    source      = string<br/>    destination = string<br/>    perms       = optional(string, "0640")<br/>  }))</pre> | `{}` | no |
| <a name="input_token_max_ttl"></a> [token\_max\_ttl](#input\_token\_max\_ttl) | Maximum TTL for tokens issued by this role | `number` | `14400` | no |
| <a name="input_token_ttl"></a> [token\_ttl](#input\_token\_ttl) | Default TTL for tokens issued by this role | `number` | `3600` | no |
| <a name="input_vault_addr"></a> [vault\_addr](#input\_vault\_addr) | Vault server address | `string` | `"https://vault.jclee.me"` | no |
| <a name="input_vault_mount"></a> [vault\_mount](#input\_vault\_mount) | Vault KV v2 mount path | `string` | `"secret"` | no |

## Outputs

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_config_files"></a> [config\_files](#output\_config\_files) | Config files map compatible with lxc-config/vm-config input format |
| <a name="output_role_id"></a> [role\_id](#output\_role\_id) | AppRole role ID for external provisioning |
| <a name="output_secret_id"></a> [secret\_id](#output\_secret\_id) | AppRole secret ID for external provisioning |

<!-- END_TF_DOCS -->
