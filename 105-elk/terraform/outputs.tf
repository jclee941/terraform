output "ilm_policy_homelab_logs" {
  description = "Name of the homelab-logs-30d ILM policy"
  value       = elasticstack_elasticsearch_index_lifecycle.homelab_logs_30d.name
}

output "index_template_logs" {
  description = "Name of the logs index template"
  value       = elasticstack_elasticsearch_index_template.logs.name
}

output "kibana_space_id" {
  description = "ID of the homelab Kibana space"
  value       = elasticstack_kibana_space.homelab.space_id
}

output "data_view_logs_id" {
  description = "ID of the Logs data view"
  value       = elasticstack_kibana_data_view.logs.id
}
