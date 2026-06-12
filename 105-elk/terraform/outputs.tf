output "ilm_policy_homelab_logs" {
  description = "Name of the homelab-logs-30d ILM policy"
  value       = module.ilm["logs_30d"].name
}

output "index_template_logs" {
  description = "Name of the logs index template"
  value       = module.index_templates["logs"].name
}

output "kibana_space_id" {
  description = "ID of the homelab Kibana space"
  value       = elasticstack_kibana_space.homelab.space_id
}

output "data_view_logs_id" {
  description = "ID of the Logs data view"
  value       = elasticstack_kibana_data_view.logs.id
}
