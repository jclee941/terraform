<!-- BEGIN_TF_DOCS -->


## Requirements

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7, < 2.0 |
| <a name="requirement_grafana"></a> [grafana](#requirement\_grafana) | ~> 4.0 |
| <a name="requirement_onepassword"></a> [onepassword](#requirement\_onepassword) | ~> 3.2 |

## Providers

## Providers

| Name | Version |
|------|---------|
| <a name="provider_grafana"></a> [grafana](#provider\_grafana) | 4.27.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Resources

## Resources

| Name | Type |
|------|------|
| [grafana_contact_point.alert_log_fallback](https://registry.terraform.io/providers/grafana/grafana/latest/docs/resources/contact_point) | resource |
| [grafana_contact_point.slack_alerts](https://registry.terraform.io/providers/grafana/grafana/latest/docs/resources/contact_point) | resource |
| [grafana_dashboard.managed](https://registry.terraform.io/providers/grafana/grafana/latest/docs/resources/dashboard) | resource |
| [grafana_folder.alerts](https://registry.terraform.io/providers/grafana/grafana/latest/docs/resources/folder) | resource |
| [grafana_folder.homelab](https://registry.terraform.io/providers/grafana/grafana/latest/docs/resources/folder) | resource |
| [grafana_folder.mcp_alerts](https://registry.terraform.io/providers/grafana/grafana/latest/docs/resources/folder) | resource |
| [grafana_notification_policy.default](https://registry.terraform.io/providers/grafana/grafana/latest/docs/resources/notification_policy) | resource |
| [grafana_rule_group.homelab_logs](https://registry.terraform.io/providers/grafana/grafana/latest/docs/resources/rule_group) | resource |
| [grafana_rule_group.infrastructure_health](https://registry.terraform.io/providers/grafana/grafana/latest/docs/resources/rule_group) | resource |
| [grafana_rule_group.mcp_alerts](https://registry.terraform.io/providers/grafana/grafana/latest/docs/resources/rule_group) | resource |
| [grafana_service_account.monitoring](https://registry.terraform.io/providers/grafana/grafana/latest/docs/resources/service_account) | resource |
| [grafana_service_account.terraform](https://registry.terraform.io/providers/grafana/grafana/latest/docs/resources/service_account) | resource |
| [grafana_service_account_token.monitoring](https://registry.terraform.io/providers/grafana/grafana/latest/docs/resources/service_account_token) | resource |
| [grafana_service_account_token.terraform](https://registry.terraform.io/providers/grafana/grafana/latest/docs/resources/service_account_token) | resource |
| [terraform_data.validate_credentials](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [grafana_data_source.elasticsearch_logs](https://registry.terraform.io/providers/grafana/grafana/latest/docs/data-sources/data_source) | data source |
| [grafana_data_source.prometheus](https://registry.terraform.io/providers/grafana/grafana/latest/docs/data-sources/data_source) | data source |

## Inputs

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_grafana_admin_password"></a> [grafana\_admin\_password](#input\_grafana\_admin\_password) | Grafana admin password used for basic auth fallback (overrides 1Password if set) | `string` | `""` | no |
| <a name="input_grafana_admin_username"></a> [grafana\_admin\_username](#input\_grafana\_admin\_username) | Grafana admin username used for basic auth fallback | `string` | `"admin"` | no |
| <a name="input_grafana_auth"></a> [grafana\_auth](#input\_grafana\_auth) | Grafana API key or service account token | `string` | `""` | no |
| <a name="input_grafana_url"></a> [grafana\_url](#input\_grafana\_url) | Grafana instance URL | `string` | `"http://192.168.50.104:3000"` | no |
| <a name="input_onepassword_vault_name"></a> [onepassword\_vault\_name](#input\_onepassword\_vault\_name) | 1Password vault name for secret lookups | `string` | `"homelab"` | no |
| <a name="input_slack_webhook_url"></a> [slack\_webhook\_url](#input\_slack\_webhook\_url) | Slack incoming webhook URL for alert notifications (fallback if not in 1Password) | `string` | `""` | no |

## Outputs

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_contact_point_fallback"></a> [contact\_point\_fallback](#output\_contact\_point\_fallback) | Name of the alert-log fallback contact point |
| <a name="output_dashboard_count"></a> [dashboard\_count](#output\_dashboard\_count) | Number of Terraform-managed dashboards |
| <a name="output_dashboard_names"></a> [dashboard\_names](#output\_dashboard\_names) | Set of managed dashboard file names |
| <a name="output_folder_uid_alerts"></a> [folder\_uid\_alerts](#output\_folder\_uid\_alerts) | UID of the Alerts Grafana folder |
| <a name="output_folder_uid_homelab"></a> [folder\_uid\_homelab](#output\_folder\_uid\_homelab) | UID of the homelab Grafana folder |
| <a name="output_folder_uid_mcp_alerts"></a> [folder\_uid\_mcp\_alerts](#output\_folder\_uid\_mcp\_alerts) | UID of the MCP Alerts Grafana folder |
| <a name="output_grafana_sa_token_monitoring"></a> [grafana\_sa\_token\_monitoring](#output\_grafana\_sa\_token\_monitoring) | Grafana read-only service account token for monitoring consumers |
| <a name="output_grafana_sa_token_terraform"></a> [grafana\_sa\_token\_terraform](#output\_grafana\_sa\_token\_terraform) | Grafana service account token for Terraform operations |
| <a name="output_notification_policy_id"></a> [notification\_policy\_id](#output\_notification\_policy\_id) | ID of the default notification policy |
| <a name="output_rule_group_names"></a> [rule\_group\_names](#output\_rule\_group\_names) | Names of all managed alert rule groups |

<!-- END_TF_DOCS -->
