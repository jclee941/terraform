<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7, < 2.0 |
| <a name="requirement_elasticstack"></a> [elasticstack](#requirement\_elasticstack) | ~> 0.13 |
| <a name="requirement_onepassword"></a> [onepassword](#requirement\_onepassword) | ~> 3.2 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_elasticstack"></a> [elasticstack](#provider\_elasticstack) | 0.14.2 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_onepassword_secrets"></a> [onepassword\_secrets](#module\_onepassword\_secrets) | ../../modules/shared/onepassword-secrets | n/a |

## Resources

| Name | Type |
|------|------|
| [elasticstack_elasticsearch_index_lifecycle.homelab_logs_30d](https://registry.terraform.io/providers/elastic/elasticstack/latest/docs/resources/elasticsearch_index_lifecycle) | resource |
| [elasticstack_elasticsearch_index_lifecycle.homelab_logs_critical_90d](https://registry.terraform.io/providers/elastic/elasticstack/latest/docs/resources/elasticsearch_index_lifecycle) | resource |
| [elasticstack_elasticsearch_index_lifecycle.homelab_logs_ephemeral_7d](https://registry.terraform.io/providers/elastic/elasticstack/latest/docs/resources/elasticsearch_index_lifecycle) | resource |
| [elasticstack_elasticsearch_index_template.logs](https://registry.terraform.io/providers/elastic/elasticstack/latest/docs/resources/elasticsearch_index_template) | resource |
| [elasticstack_elasticsearch_index_template.logs_cloudflare_workers](https://registry.terraform.io/providers/elastic/elasticstack/latest/docs/resources/elasticsearch_index_template) | resource |
| [elasticstack_elasticsearch_index_template.logs_critical](https://registry.terraform.io/providers/elastic/elasticstack/latest/docs/resources/elasticsearch_index_template) | resource |
| [elasticstack_elasticsearch_index_template.logs_ephemeral](https://registry.terraform.io/providers/elastic/elasticstack/latest/docs/resources/elasticsearch_index_template) | resource |
| [elasticstack_elasticsearch_snapshot_repository.homelab_backups](https://registry.terraform.io/providers/elastic/elasticstack/latest/docs/resources/elasticsearch_snapshot_repository) | resource |
| [elasticstack_kibana_data_view.logs](https://registry.terraform.io/providers/elastic/elasticstack/latest/docs/resources/kibana_data_view) | resource |
| [elasticstack_kibana_space.homelab](https://registry.terraform.io/providers/elastic/elasticstack/latest/docs/resources/kibana_space) | resource |
| [terraform_data.validate_credentials](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_elasticsearch_password"></a> [elasticsearch\_password](#input\_elasticsearch\_password) | Elasticsearch password (empty if xpack security disabled) | `string` | `""` | no |
| <a name="input_elasticsearch_url"></a> [elasticsearch\_url](#input\_elasticsearch\_url) | Elasticsearch endpoint URL | `string` | `"http://192.168.50.105:9200"` | no |
| <a name="input_elasticsearch_username"></a> [elasticsearch\_username](#input\_elasticsearch\_username) | Elasticsearch username (empty if xpack security disabled) | `string` | `"elastic"` | no |
| <a name="input_kibana_url"></a> [kibana\_url](#input\_kibana\_url) | Kibana endpoint URL | `string` | `"http://192.168.50.105:5601"` | no |
| <a name="input_onepassword_vault_name"></a> [onepassword\_vault\_name](#input\_onepassword\_vault\_name) | 1Password vault name for secret lookups | `string` | `"homelab"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_data_view_logs_id"></a> [data\_view\_logs\_id](#output\_data\_view\_logs\_id) | ID of the Logs data view |
| <a name="output_ilm_policy_homelab_logs"></a> [ilm\_policy\_homelab\_logs](#output\_ilm\_policy\_homelab\_logs) | Name of the homelab-logs-30d ILM policy |
| <a name="output_index_template_logs"></a> [index\_template\_logs](#output\_index\_template\_logs) | Name of the logs index template |
| <a name="output_kibana_space_id"></a> [kibana\_space\_id](#output\_kibana\_space\_id) | ID of the homelab Kibana space |
<!-- END_TF_DOCS -->
