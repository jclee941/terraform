
resource "grafana_folder" "homelab" {
  title = "Homelab"
}

resource "grafana_folder" "alerts" {
  title = "Alerts"
}

resource "grafana_folder" "opencode" {
  title = "OpenCode"
}

resource "grafana_folder" "mcp_alerts" {
  title = "MCP Alerts"
}

resource "grafana_data_source" "prometheus" {
  type = "prometheus"
  name = "Prometheus"
  url  = "http://prometheus:9090"

  is_default = true

  json_data_encoded = jsonencode({
    httpMethod = "POST"
  })
}

resource "grafana_data_source" "elasticsearch_logs" {
  type = "elasticsearch"
  name = "Elasticsearch"
  url  = "http://192.168.50.105:9200"

  json_data_encoded = jsonencode({
    index     = "logs-*"
    timeField = "@timestamp"
    esVersion = "8.0.0"
  })
}

resource "grafana_data_source" "elasticsearch_filebeat" {
  type = "elasticsearch"
  name = "Elasticsearch-Filebeat"
  url  = "http://192.168.50.105:9200"

  json_data_encoded = jsonencode({
    index     = "filebeat-*"
    timeField = "@timestamp"
    esVersion = "8.0.0"
  })
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

resource "grafana_contact_point" "n8n_webhook" {
  name = "n8n-webhook"

  webhook {
    url = var.n8n_webhook_url
  }
}

resource "grafana_contact_point" "alert_log_fallback" {
  name = "alert-log-fallback"

  webhook {
    url = "${var.grafana_url}/api/alertmanager/grafana/api/v2/alerts"
  }
}

resource "grafana_notification_policy" "default" {
  group_by      = ["alertname", "grafana_folder"]
  contact_point = grafana_contact_point.n8n_webhook.name

  group_wait      = "30s"
  group_interval  = "5m"
  repeat_interval = "4h"

  policy {
    matcher {
      label = "severity"
      match = "="
      value = "critical"
    }
    contact_point   = grafana_contact_point.n8n_webhook.name
    repeat_interval = "1h"
  }

  policy {
    matcher {
      label = "severity"
      match = "="
      value = "warning"
    }
    contact_point   = grafana_contact_point.n8n_webhook.name
    repeat_interval = "4h"
  }

  policy {
    matcher {
      label = "severity"
      match = "="
      value = "info"
    }
    contact_point   = grafana_contact_point.alert_log_fallback.name
    repeat_interval = "12h"
  }
}

resource "grafana_rule_group" "homelab_logs" {
  name             = "homelab-logs"
  folder_uid       = grafana_folder.alerts.uid
  interval_seconds = 60

  rule {
    name      = "high-error-rate"
    condition = "C"
    for       = "2m"

    data {
      ref_id         = "A"
      datasource_uid = grafana_data_source.elasticsearch_logs.uid

      relative_time_range {
        from = 300
        to   = 0
      }

      model = jsonencode({
        query  = "_exists_:error_classification AND error_severity:(critical OR high OR medium)"
        metric = ["count"]
      })
    }

    data {
      ref_id         = "B"
      datasource_uid = "-100"

      relative_time_range {
        from = 0
        to   = 0
      }

      model = jsonencode({
        type       = "reduce"
        reducer    = "sum"
        expression = "A"
      })
    }

    data {
      ref_id         = "C"
      datasource_uid = "-100"

      relative_time_range {
        from = 0
        to   = 0
      }

      model = jsonencode({
        type       = "threshold"
        conditions = [{ evaluator = { type = "gt", params = [100] } }]
        expression = "B"
      })
    }

    labels = {
      severity = "warning"
    }

    annotations = {
      summary     = "High error rate detected"
      description = "Error count exceeded threshold (>100) in the last 5 minutes"
    }
  }

  rule {
    name      = "critical-error-spike"
    condition = "C"
    for       = "1m"

    data {
      ref_id         = "A"
      datasource_uid = grafana_data_source.elasticsearch_logs.uid

      relative_time_range {
        from = 60
        to   = 0
      }

      model = jsonencode({
        query  = "error_severity:critical"
        metric = ["count"]
      })
    }

    data {
      ref_id         = "B"
      datasource_uid = "-100"

      relative_time_range {
        from = 0
        to   = 0
      }

      model = jsonencode({
        type       = "reduce"
        reducer    = "sum"
        expression = "A"
      })
    }

    data {
      ref_id         = "C"
      datasource_uid = "-100"

      relative_time_range {
        from = 0
        to   = 0
      }

      model = jsonencode({
        type       = "threshold"
        conditions = [{ evaluator = { type = "gt", params = [5] } }]
        expression = "B"
      })
    }

    labels = {
      severity = "critical"
    }

    annotations = {
      summary     = "Critical error spike"
      description = "More than 5 critical errors in 1 minute"
    }
  }

  rule {
    name      = "gateway-errors"
    condition = "C"
    for       = "2m"

    data {
      ref_id         = "A"
      datasource_uid = grafana_data_source.elasticsearch_logs.uid

      relative_time_range {
        from = 300
        to   = 0
      }

      model = jsonencode({
        query  = "error_classification:GATEWAY_ERROR"
        metric = ["count"]
      })
    }

    data {
      ref_id         = "B"
      datasource_uid = "-100"

      relative_time_range {
        from = 0
        to   = 0
      }

      model = jsonencode({
        type       = "reduce"
        reducer    = "sum"
        expression = "A"
      })
    }

    data {
      ref_id         = "C"
      datasource_uid = "-100"

      relative_time_range {
        from = 0
        to   = 0
      }

      model = jsonencode({
        type       = "threshold"
        conditions = [{ evaluator = { type = "gt", params = [10] } }]
        expression = "B"
      })
    }

    labels = {
      severity = "warning"
    }

    annotations = {
      summary     = "Gateway errors (502/503)"
      description = "More than 10 gateway errors in 5 minutes"
    }
  }

  rule {
    name      = "client-errors-spike"
    condition = "C"
    for       = "3m"

    data {
      ref_id         = "A"
      datasource_uid = grafana_data_source.elasticsearch_logs.uid

      relative_time_range {
        from = 300
        to   = 0
      }

      model = jsonencode({
        query  = "host:traefik AND message:(400 OR 401 OR 403 OR 404 OR 405 OR 429)"
        metric = ["count"]
      })
    }

    data {
      ref_id         = "B"
      datasource_uid = "-100"

      relative_time_range {
        from = 0
        to   = 0
      }

      model = jsonencode({
        type       = "reduce"
        reducer    = "sum"
        expression = "A"
      })
    }

    data {
      ref_id         = "C"
      datasource_uid = "-100"

      relative_time_range {
        from = 0
        to   = 0
      }

      model = jsonencode({
        type       = "threshold"
        conditions = [{ evaluator = { type = "gt", params = [100] } }]
        expression = "B"
      })
    }

    labels = {
      severity = "info"
    }

    annotations = {
      summary     = "Client errors spike (4xx)"
      description = "More than 100 client errors (4xx) in 5 minutes"
    }
  }

  rule {
    name      = "host-silent"
    condition = "C"
    for       = "5m"

    data {
      ref_id         = "A"
      datasource_uid = grafana_data_source.elasticsearch_logs.uid

      relative_time_range {
        from = 600
        to   = 0
      }

      model = jsonencode({
        query   = "host:(traefik OR grafana OR elk OR glitchtip OR mcphub OR runner OR oc OR supabase OR archon)"
        metric  = ["count"]
        groupBy = ["host.keyword"]
      })
    }

    data {
      ref_id         = "B"
      datasource_uid = "-100"

      relative_time_range {
        from = 0
        to   = 0
      }

      model = jsonencode({
        type       = "reduce"
        reducer    = "sum"
        expression = "A"
      })
    }

    data {
      ref_id         = "C"
      datasource_uid = "-100"

      relative_time_range {
        from = 0
        to   = 0
      }

      model = jsonencode({
        type       = "threshold"
        conditions = [{ evaluator = { type = "lt", params = [5] } }]
        expression = "B"
      })
    }

    labels = {
      severity = "warning"
    }

    annotations = {
      summary     = "Host silent"
      description = "Host {{ $labels.host_keyword }} has fewer than 5 log entries in 10 minutes"
    }
  }
}

resource "grafana_rule_group" "infrastructure_health" {
  name             = "infrastructure-health"
  folder_uid       = grafana_folder.alerts.uid
  interval_seconds = 60

  rule {
    name      = "service-down"
    condition = "C"

    data {
      ref_id         = "A"
      datasource_uid = grafana_data_source.prometheus.uid

      relative_time_range {
        from = 300
        to   = 0
      }

      model = jsonencode({
        expr = "probe_success == 0"
      })
    }

    data {
      ref_id         = "C"
      datasource_uid = "-100"

      relative_time_range {
        from = 0
        to   = 0
      }

      model = jsonencode({
        type       = "threshold"
        conditions = [{ evaluator = { type = "gt", params = [0] } }]
      })
    }

    labels = {
      severity = "critical"
    }

    annotations = {
      summary     = "Service down"
      description = "Blackbox probe failed for {{ $labels.instance }}"
    }
  }

  rule {
    name      = "disk-usage-high"
    condition = "C"

    data {
      ref_id         = "A"
      datasource_uid = grafana_data_source.prometheus.uid

      relative_time_range {
        from = 300
        to   = 0
      }

      model = jsonencode({
        expr = "(1 - node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100 > 80"
      })
    }

    data {
      ref_id         = "C"
      datasource_uid = "-100"

      relative_time_range {
        from = 0
        to   = 0
      }

      model = jsonencode({
        type       = "threshold"
        conditions = [{ evaluator = { type = "gt", params = [0] } }]
      })
    }

    labels = {
      severity = "warning"
    }

    annotations = {
      summary     = "Disk usage high"
      description = "Disk usage above 80% on {{ $labels.instance }}"
    }
  }

  rule {
    name      = "disk-usage-critical"
    condition = "C"

    data {
      ref_id         = "A"
      datasource_uid = grafana_data_source.prometheus.uid

      relative_time_range {
        from = 300
        to   = 0
      }

      model = jsonencode({
        expr = "(1 - node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100 > 90"
      })
    }

    data {
      ref_id         = "C"
      datasource_uid = "-100"

      relative_time_range {
        from = 0
        to   = 0
      }

      model = jsonencode({
        type       = "threshold"
        conditions = [{ evaluator = { type = "gt", params = [0] } }]
      })
    }

    labels = {
      severity = "critical"
    }

    annotations = {
      summary     = "Disk usage critical"
      description = "Disk usage above 90% on {{ $labels.instance }}"
    }
  }

  rule {
    name      = "ssl-cert-expiry"
    condition = "C"
    for       = "10m"

    data {
      ref_id         = "A"
      datasource_uid = grafana_data_source.prometheus.uid

      relative_time_range {
        from = 300
        to   = 0
      }

      model = jsonencode({
        expr = "(probe_ssl_earliest_cert_expiry - time()) / 86400"
      })
    }

    data {
      ref_id         = "C"
      datasource_uid = "-100"

      relative_time_range {
        from = 0
        to   = 0
      }

      model = jsonencode({
        type       = "threshold"
        conditions = [{ evaluator = { type = "lt", params = [7] } }]
      })
    }

    labels = {
      severity = "warning"
    }

    annotations = {
      summary     = "SSL certificate expiring"
      description = "SSL certificate for {{ $labels.instance }} expires in less than 7 days"
    }
  }

  rule {
    name      = "memory-pressure"
    condition = "C"
    for       = "5m"

    data {
      ref_id         = "A"
      datasource_uid = grafana_data_source.prometheus.uid

      relative_time_range {
        from = 300
        to   = 0
      }

      model = jsonencode({
        expr = "(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100"
      })
    }

    data {
      ref_id         = "C"
      datasource_uid = "-100"

      relative_time_range {
        from = 0
        to   = 0
      }

      model = jsonencode({
        type       = "threshold"
        conditions = [{ evaluator = { type = "gt", params = [85] } }]
      })
    }

    labels = {
      severity = "warning"
    }

    annotations = {
      summary     = "Memory pressure"
      description = "Memory usage above 85% on {{ $labels.instance }}"
    }
  }

  rule {
    name      = "container-restart-loop"
    condition = "C"
    for       = "5m"

    data {
      ref_id         = "A"
      datasource_uid = grafana_data_source.elasticsearch_logs.uid

      relative_time_range {
        from = 3600
        to   = 0
      }

      model = jsonencode({
        query  = "message:(\"container restart\" OR Restarting OR unhealthy OR OOMKilled) AND host:(supabase OR archon OR mcphub OR elk OR glitchtip OR grafana)"
        metric = ["count"]
      })
    }

    data {
      ref_id         = "B"
      datasource_uid = "-100"

      relative_time_range {
        from = 0
        to   = 0
      }

      model = jsonencode({
        type       = "reduce"
        reducer    = "sum"
        expression = "A"
      })
    }

    data {
      ref_id         = "C"
      datasource_uid = "-100"

      relative_time_range {
        from = 0
        to   = 0
      }

      model = jsonencode({
        type       = "threshold"
        conditions = [{ evaluator = { type = "gt", params = [5] } }]
        expression = "B"
      })
    }

    labels = {
      severity = "warning"
    }

    annotations = {
      summary     = "Container restart loop"
      description = "More than 5 container restart events in 1 hour on {{ $labels.host }}"
    }
  }
}

resource "grafana_rule_group" "opencode_alerts" {
  name             = "opencode-alerts"
  folder_uid       = grafana_folder.opencode.uid
  interval_seconds = 60

  rule {
    name      = "opencode-session-activity"
    condition = "C"
    for       = "1m"

    data {
      ref_id         = "A"
      datasource_uid = grafana_data_source.elasticsearch_logs.uid

      relative_time_range {
        from = 300
        to   = 0
      }

      model = jsonencode({
        query  = "service:opencode OR job:opencode"
        metric = ["count"]
      })
    }

    data {
      ref_id         = "B"
      datasource_uid = "-100"

      relative_time_range {
        from = 0
        to   = 0
      }

      model = jsonencode({
        type       = "reduce"
        reducer    = "sum"
        expression = "A"
      })
    }

    data {
      ref_id         = "C"
      datasource_uid = "-100"

      relative_time_range {
        from = 0
        to   = 0
      }

      model = jsonencode({
        type       = "threshold"
        conditions = [{ evaluator = { type = "gt", params = [10] } }]
        expression = "B"
      })
    }

    labels = {
      severity = "info"
    }

    annotations = {
      summary     = "OpenCode session activity"
      description = "OpenCode session activity exceeded threshold (>10 events in 5 minutes)"
    }
  }

  rule {
    name      = "opencode-errors"
    condition = "C"
    for       = "2m"

    data {
      ref_id         = "A"
      datasource_uid = grafana_data_source.elasticsearch_logs.uid

      relative_time_range {
        from = 300
        to   = 0
      }

      model = jsonencode({
        query  = "(service:opencode OR job:opencode) AND _exists_:error_classification"
        metric = ["count"]
      })
    }

    data {
      ref_id         = "B"
      datasource_uid = "-100"

      relative_time_range {
        from = 0
        to   = 0
      }

      model = jsonencode({
        type       = "reduce"
        reducer    = "sum"
        expression = "A"
      })
    }

    data {
      ref_id         = "C"
      datasource_uid = "-100"

      relative_time_range {
        from = 0
        to   = 0
      }

      model = jsonencode({
        type       = "threshold"
        conditions = [{ evaluator = { type = "gt", params = [5] } }]
        expression = "B"
      })
    }

    labels = {
      severity = "warning"
    }

    annotations = {
      summary     = "OpenCode errors detected"
      description = "More than 5 OpenCode error events in 5 minutes"
    }
  }
}

resource "grafana_rule_group" "mcp_alerts" {
  name             = "mcp-alerts"
  folder_uid       = grafana_folder.mcp_alerts.uid
  interval_seconds = 60

  rule {
    name      = "mcp-error-logs"
    condition = "C"
    for       = "1m"

    data {
      ref_id         = "A"
      datasource_uid = grafana_data_source.elasticsearch_logs.uid

      relative_time_range {
        from = 600
        to   = 0
      }

      model = jsonencode({
        query  = "(service:mcp OR service:mcphub OR job:mcp) AND _exists_:error_classification"
        metric = ["count"]
      })
    }

    data {
      ref_id         = "B"
      datasource_uid = "-100"

      relative_time_range {
        from = 0
        to   = 0
      }

      model = jsonencode({
        type       = "reduce"
        reducer    = "sum"
        expression = "A"
      })
    }

    data {
      ref_id         = "C"
      datasource_uid = "-100"

      relative_time_range {
        from = 0
        to   = 0
      }

      model = jsonencode({
        type       = "threshold"
        conditions = [{ evaluator = { type = "gt", params = [5] } }]
        expression = "B"
      })
    }

    labels = {
      severity = "warning"
    }

    annotations = {
      summary     = "MCP error logs"
      description = "More than 5 MCP error events in 10 minutes"
    }
  }
}
