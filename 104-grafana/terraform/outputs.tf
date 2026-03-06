output "folder_uid_homelab" {
  description = "UID of the homelab Grafana folder"
  value       = grafana_folder.homelab.uid
}

output "folder_uid_alerts" {
  description = "UID of the Alerts Grafana folder"
  value       = grafana_folder.alerts.uid
}

output "folder_uid_mcp_alerts" {
  description = "UID of the MCP Alerts Grafana folder"
  value       = grafana_folder.mcp_alerts.uid
}

output "dashboard_count" {
  description = "Number of Terraform-managed dashboards"
  value       = length(grafana_dashboard.managed)
}

output "dashboard_names" {
  description = "Set of managed dashboard file names"
  value       = keys(grafana_dashboard.managed)
}


output "contact_point_fallback" {
  description = "Name of the alert-log fallback contact point"
  value       = grafana_contact_point.alert_log_fallback.name
}

output "notification_policy_id" {
  description = "ID of the default notification policy"
  value       = grafana_notification_policy.default.id
}

output "rule_group_names" {
  description = "Names of all managed alert rule groups"
  value = [
    grafana_rule_group.homelab_logs.name,
    grafana_rule_group.infrastructure_health.name,
    grafana_rule_group.mcp_alerts.name,
  ]
}
