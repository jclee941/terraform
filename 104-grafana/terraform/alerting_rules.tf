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
