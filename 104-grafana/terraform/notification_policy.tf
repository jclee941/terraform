resource "grafana_notification_policy" "default" {
  group_by      = ["alertname", "grafana_folder"]
  contact_point = grafana_contact_point.alert_log_fallback.name

  group_wait      = "30s"
  group_interval  = "5m"
  repeat_interval = "4h"

  dynamic "policy" {
    for_each = { for severity in(local._slack_enabled ? ["critical", "warning"] : []) : severity => { severity = severity } }
    content {
      matcher {
        label = "severity"
        match = "="
        value = policy.value.severity
      }
      contact_point   = grafana_contact_point.slack_alerts[0].name
      repeat_interval = policy.value.severity == "critical" ? "1h" : "4h"
    }
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
