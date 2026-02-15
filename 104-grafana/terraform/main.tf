
resource "grafana_folder" "homelab" {
  title = "Homelab"
}

resource "grafana_folder" "alerts" {
  title = "Alerts"
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

    data {
      ref_id         = "A"
      datasource_uid = grafana_data_source.elasticsearch_logs.uid

      relative_time_range {
        from = 300
        to   = 0
      }

      model = jsonencode({
        query  = "level:error"
        metric = ["count"]
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
      })
    }

    labels = {
      severity = "warning"
    }

    annotations = {
      summary     = "High error rate detected"
      description = "Error count exceeded threshold in the last 5 minutes"
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
}
