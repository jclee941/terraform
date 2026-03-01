
resource "grafana_folder" "homelab" {
  title = "homelab"
}

resource "grafana_folder" "alerts" {
  title = "Alerts"
}

resource "grafana_folder" "mcp_alerts" {
  title = "MCP Alerts"
}

data "grafana_data_source" "prometheus" {
  name = "Prometheus"
}

data "grafana_data_source" "elasticsearch_logs" {
  name = "Elasticsearch"
}

locals {
  dashboard_files = fileset("${path.module}/../dashboards", "*.json")
}

resource "grafana_dashboard" "managed" {
  for_each = local.dashboard_files

  folder    = grafana_folder.homelab.id
  overwrite = true

  config_json = file("${path.module}/../dashboards/${each.value}")
}
