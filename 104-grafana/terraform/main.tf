
resource "grafana_folder" "homelab" {
  title = "homelab"
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

data "grafana_data_source" "prometheus" {
  name = "Prometheus"
}

data "grafana_data_source" "elasticsearch_logs" {
  name = "Elasticsearch"
}

data "grafana_data_source" "elasticsearch_filebeat" {
  name = "Elasticsearch-Filebeat"
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

# -----------------------------------------------------------------------------
# Alert Rule Definitions (data-driven)
# -----------------------------------------------------------------------------

locals {
  # Elasticsearch-based alert rules (3 data blocks: query → reduce → threshold)
  # Model uses metrics/bucketAggs/timeField format required by Grafana ES alerting backend.
  es_alert_rules = {
    # Group: homelab_logs
    "high-error-rate" = {
      group        = "homelab_logs"
      query        = "_exists_:error_classification AND error_severity:(critical OR high OR medium)"
      from         = 600
      threshold    = 500
      condition    = "gt"
      severity     = "warning"
      for_duration = "5m"
      group_by     = []
      summary      = "High error rate detected"
      description  = "Error count exceeded threshold (>500) in the last 10 minutes"
    }
    "critical-error-spike" = {
      group        = "homelab_logs"
      query        = "error_severity:critical"
      from         = 60
      threshold    = 5
      condition    = "gt"
      severity     = "critical"
      for_duration = "1m"
      group_by     = []
      summary      = "Critical error spike"
      description  = "More than 5 critical errors in 1 minute"
    }
    "gateway-errors" = {
      group        = "homelab_logs"
      query        = "error_classification:GATEWAY_ERROR"
      from         = 300
      threshold    = 10
      condition    = "gt"
      severity     = "warning"
      for_duration = "2m"
      group_by     = []
      summary      = "Gateway errors (502/503)"
      description  = "More than 10 gateway errors in 5 minutes"
    }
    "client-errors-spike" = {
      group        = "homelab_logs"
      query        = "host_name:traefik AND message:(400 OR 401 OR 403 OR 404 OR 405 OR 429)"
      from         = 300
      threshold    = 200
      condition    = "gt"
      severity     = "warning"
      for_duration = "5m"
      group_by     = []
      summary      = "Client errors spike (4xx)"
      description  = "More than 200 client errors (4xx) in 5 minutes"
    }
    "host-silent" = {
      group        = "homelab_logs"
      query        = "host_name:(traefik OR grafana OR elk OR glitchtip OR mcphub OR runner OR oc OR supabase OR archon)"
      from         = 900
      threshold    = 5
      condition    = "lt"
      severity     = "warning"
      for_duration = "10m"
      group_by     = ["host_name.keyword"]
      summary      = "Host silent"
      description  = "Host {{ $labels.host_name_keyword }} has fewer than 5 log entries in 15 minutes"
    }
    # Group: infrastructure_health (ES rule in mixed group)
    "container-restart-loop" = {
      group        = "infrastructure_health"
      query        = "message:(\"container restart\" OR Restarting OR unhealthy OR OOMKilled) AND host:(supabase OR archon OR mcphub OR elk OR glitchtip OR grafana)"
      from         = 3600
      threshold    = 5
      condition    = "gt"
      severity     = "warning"
      for_duration = "5m"
      group_by     = []
      summary      = "Container restart loop"
      description  = "More than 5 container restart events in 1 hour on {{ $labels.host }}"
    }
    # Group: opencode_alerts
    "opencode-errors" = {
      group        = "opencode_alerts"
      query        = "(service:opencode OR job:opencode) AND _exists_:error_classification AND NOT error_severity:low"
      from         = 300
      threshold    = 5
      condition    = "gt"
      severity     = "warning"
      for_duration = "2m"
      group_by     = []
      summary      = "OpenCode errors detected"
      description  = "More than 5 OpenCode error events in 5 minutes"
    }
    # Group: mcp_alerts
    "mcp-error-logs" = {
      group        = "mcp_alerts"
      query        = "(service:mcp OR service:mcphub OR job:mcp) AND _exists_:error_classification AND NOT error_severity:low"
      from         = 600
      threshold    = 5
      condition    = "gt"
      severity     = "warning"
      for_duration = "1m"
      group_by     = []
      summary      = "MCP error logs"
      description  = "More than 5 MCP error events in 10 minutes"
    }
    "service-log-gap" = {
      group        = "homelab_logs"
      query        = "fields.service:(traefik OR grafana OR elk OR glitchtip OR supabase OR archon OR mcphub OR runner)"
      from         = 3600
      threshold    = 1
      condition    = "lt"
      severity     = "warning"
      for_duration = "10m"
      group_by     = []
      summary      = "Service log collection gap detected"
      description  = "Service has sent fewer than 1 log events in the past 60 minutes — filebeat may be down or misconfigured"
    }
  }

  # Prometheus-based alert rules (2 data blocks: expr → threshold)
  prometheus_alert_rules = {
    # All in group: infrastructure_health
    "service-down" = {
      group        = "infrastructure_health"
      expr         = "probe_success{instance!~\".*:80\"} == 0"
      from         = 300
      threshold    = 0
      condition    = "gt"
      severity     = "critical"
      for_duration = "2m"
      summary      = "Service down"
      description  = "Blackbox probe failed for {{ $labels.instance }}"
    }
    "disk-usage-high" = {
      group        = "infrastructure_health"
      expr         = "(1 - node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100 > 80"
      from         = 300
      threshold    = 0
      condition    = "gt"
      severity     = "warning"
      for_duration = "5m"
      summary      = "Disk usage high"
      description  = "Disk usage above 80% on {{ $labels.instance }}"
    }
    "disk-usage-critical" = {
      group        = "infrastructure_health"
      expr         = "(1 - node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100 > 90"
      from         = 300
      threshold    = 0
      condition    = "gt"
      severity     = "critical"
      for_duration = "5m"
      summary      = "Disk usage critical"
      description  = "Disk usage above 90% on {{ $labels.instance }}"
    }
    "memory-pressure" = {
      group        = "infrastructure_health"
      expr         = "(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100"
      from         = 300
      threshold    = 85
      condition    = "gt"
      severity     = "warning"
      for_duration = "5m"
      summary      = "Memory pressure"
      description  = "Memory usage above 85% on {{ $labels.instance }}"
    }
    "cpu-usage-high" = {
      group        = "infrastructure_health"
      expr         = "100 - (avg by(instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)"
      from         = 600
      threshold    = 90
      condition    = "gt"
      severity     = "warning"
      for_duration = "10m"
      summary      = "CPU usage high"
      description  = "CPU usage above 90% on {{ $labels.instance }} for 10 minutes"
    }
    "prometheus-target-down" = {
      group        = "infrastructure_health"
      expr         = "up == 0"
      from         = 300
      threshold    = 0
      condition    = "gt"
      severity     = "critical"
      for_duration = "3m"
      summary      = "Prometheus target down"
      description  = "Prometheus scrape target {{ $labels.instance }} (job={{ $labels.job }}) is down"
    }
    "node-load-high" = {
      group        = "infrastructure_health"
      expr         = "node_load15 / count without(cpu, mode) (node_cpu_seconds_total{mode=\"idle\"}) > 2"
      from         = 900
      threshold    = 0
      condition    = "gt"
      severity     = "warning"
      for_duration = "15m"
      summary      = "Node load high"
      description  = "15-min load average is over 2x CPU count on {{ $labels.instance }}"
    }
    "logstash-collection-stop" = {
      group        = "infrastructure_health"
      expr         = "sum(rate(logstash_events_in_total[5m]))"
      from         = 600
      threshold    = 0.001
      condition    = "lt"
      severity     = "critical"
      for_duration = "10m"
      summary      = "Log collection stopped"
      description  = "Logstash has received zero events for 10 minutes — filebeat or pipeline may be down"
    }
  }

  # Group filters
  homelab_logs_es   = { for k, v in local.es_alert_rules : k => v if v.group == "homelab_logs" }
  infra_health_es   = { for k, v in local.es_alert_rules : k => v if v.group == "infrastructure_health" }
  infra_health_prom = { for k, v in local.prometheus_alert_rules : k => v if v.group == "infrastructure_health" }
  opencode_es       = { for k, v in local.es_alert_rules : k => v if v.group == "opencode_alerts" }
  mcp_es            = { for k, v in local.es_alert_rules : k => v if v.group == "mcp_alerts" }
}

# -----------------------------------------------------------------------------
# Alert Rule Groups
# -----------------------------------------------------------------------------

resource "grafana_rule_group" "homelab_logs" {
  name             = "homelab-logs"
  folder_uid       = grafana_folder.alerts.uid
  interval_seconds = 60

  dynamic "rule" {
    for_each = local.homelab_logs_es
    content {
      name      = rule.key
      condition = "C"
      for       = rule.value.for_duration

      data {
        ref_id         = "A"
        datasource_uid = data.grafana_data_source.elasticsearch_logs.uid

        relative_time_range {
          from = rule.value.from
          to   = 0
        }

        model = jsonencode(merge(
          {
            query   = rule.value.query
            metrics = [{ type = "count", id = "1" }]
            bucketAggs = length(rule.value.group_by) > 0 ? [
              { type = "terms", id = "3", field = rule.value.group_by[0], settings = { size = "10", order = "desc", orderBy = "1" } },
              { type = "date_histogram", id = "2", field = "@timestamp", settings = { interval = "auto" } }
              ] : [
              { type = "date_histogram", id = "2", field = "@timestamp", settings = { interval = "auto" } }
            ]
            timeField = "@timestamp"
          }
        ))
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
          conditions = [{ evaluator = { type = rule.value.condition, params = [rule.value.threshold] } }]
          expression = "B"
        })
      }

      labels = {
        severity = rule.value.severity
      }

      annotations = {
        summary     = rule.value.summary
        description = rule.value.description
      }

      no_data_state  = "OK"
      exec_err_state = "OK"
    }
  }
}

resource "grafana_rule_group" "infrastructure_health" {
  name             = "infrastructure-health"
  folder_uid       = grafana_folder.alerts.uid
  interval_seconds = 60

  dynamic "rule" {
    for_each = local.infra_health_prom
    content {
      name      = rule.key
      condition = "C"
      for       = rule.value.for_duration

      data {
        ref_id         = "A"
        datasource_uid = data.grafana_data_source.prometheus.uid

        relative_time_range {
          from = rule.value.from
          to   = 0
        }

        model = jsonencode({
          expr = rule.value.expr
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
          conditions = [{ evaluator = { type = rule.value.condition, params = [rule.value.threshold] } }]
          expression = "A"
        })
      }

      labels = {
        severity = rule.value.severity
      }

      annotations = {
        summary     = rule.value.summary
        description = rule.value.description
      }

      no_data_state  = "OK"
      exec_err_state = "OK"
    }
  }

  dynamic "rule" {
    for_each = local.infra_health_es
    content {
      name      = rule.key
      condition = "C"
      for       = rule.value.for_duration

      data {
        ref_id         = "A"
        datasource_uid = data.grafana_data_source.elasticsearch_logs.uid

        relative_time_range {
          from = rule.value.from
          to   = 0
        }

        model = jsonencode(merge(
          {
            query   = rule.value.query
            metrics = [{ type = "count", id = "1" }]
            bucketAggs = length(rule.value.group_by) > 0 ? [
              { type = "terms", id = "3", field = rule.value.group_by[0], settings = { size = "10", order = "desc", orderBy = "1" } },
              { type = "date_histogram", id = "2", field = "@timestamp", settings = { interval = "auto" } }
              ] : [
              { type = "date_histogram", id = "2", field = "@timestamp", settings = { interval = "auto" } }
            ]
            timeField = "@timestamp"
          }
        ))
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
          conditions = [{ evaluator = { type = rule.value.condition, params = [rule.value.threshold] } }]
          expression = "B"
        })
      }

      labels = {
        severity = rule.value.severity
      }

      annotations = {
        summary     = rule.value.summary
        description = rule.value.description
      }

      no_data_state  = "OK"
      exec_err_state = "OK"
    }
  }
}

resource "grafana_rule_group" "opencode_alerts" {
  name             = "opencode-alerts"
  folder_uid       = grafana_folder.opencode.uid
  interval_seconds = 60

  dynamic "rule" {
    for_each = local.opencode_es
    content {
      name      = rule.key
      condition = "C"
      for       = rule.value.for_duration

      data {
        ref_id         = "A"
        datasource_uid = data.grafana_data_source.elasticsearch_logs.uid

        relative_time_range {
          from = rule.value.from
          to   = 0
        }

        model = jsonencode(merge(
          {
            query   = rule.value.query
            metrics = [{ type = "count", id = "1" }]
            bucketAggs = length(rule.value.group_by) > 0 ? [
              { type = "terms", id = "3", field = rule.value.group_by[0], settings = { size = "10", order = "desc", orderBy = "1" } },
              { type = "date_histogram", id = "2", field = "@timestamp", settings = { interval = "auto" } }
              ] : [
              { type = "date_histogram", id = "2", field = "@timestamp", settings = { interval = "auto" } }
            ]
            timeField = "@timestamp"
          }
        ))
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
          conditions = [{ evaluator = { type = rule.value.condition, params = [rule.value.threshold] } }]
          expression = "B"
        })
      }

      labels = {
        severity = rule.value.severity
      }

      annotations = {
        summary     = rule.value.summary
        description = rule.value.description
      }

      no_data_state  = "OK"
      exec_err_state = "OK"
    }
  }
}

resource "grafana_rule_group" "mcp_alerts" {
  name             = "mcp-alerts"
  folder_uid       = grafana_folder.mcp_alerts.uid
  interval_seconds = 60

  dynamic "rule" {
    for_each = local.mcp_es
    content {
      name      = rule.key
      condition = "C"
      for       = rule.value.for_duration

      data {
        ref_id         = "A"
        datasource_uid = data.grafana_data_source.elasticsearch_logs.uid

        relative_time_range {
          from = rule.value.from
          to   = 0
        }

        model = jsonencode(merge(
          {
            query   = rule.value.query
            metrics = [{ type = "count", id = "1" }]
            bucketAggs = length(rule.value.group_by) > 0 ? [
              { type = "terms", id = "3", field = rule.value.group_by[0], settings = { size = "10", order = "desc", orderBy = "1" } },
              { type = "date_histogram", id = "2", field = "@timestamp", settings = { interval = "auto" } }
              ] : [
              { type = "date_histogram", id = "2", field = "@timestamp", settings = { interval = "auto" } }
            ]
            timeField = "@timestamp"
          }
        ))
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
          conditions = [{ evaluator = { type = rule.value.condition, params = [rule.value.threshold] } }]
          expression = "B"
        })
      }

      labels = {
        severity = rule.value.severity
      }

      annotations = {
        summary     = rule.value.summary
        description = rule.value.description
      }

      no_data_state  = "OK"
      exec_err_state = "OK"
    }
  }
}
