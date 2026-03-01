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
    continue        = true
  }

  policy {
    matcher {
      label = "severity"
      match = "="
      value = "critical"
    }
    contact_point   = grafana_contact_point.n8n_glitchtip_webhook.name
    repeat_interval = "1h"
    continue        = true
  }

  dynamic "policy" {
    for_each = local._slack_enabled ? [1] : []
    content {
      matcher {
        label = "severity"
        match = "="
        value = "critical"
      }
      contact_point   = grafana_contact_point.slack_alerts[0].name
      repeat_interval = "1h"
    }
  }

  policy {
    matcher {
      label = "severity"
      match = "="
      value = "warning"
    }
    contact_point   = grafana_contact_point.n8n_webhook.name
    repeat_interval = "4h"
    continue        = true
  }

  policy {
    matcher {
      label = "severity"
      match = "="
      value = "warning"
    }
    contact_point   = grafana_contact_point.n8n_glitchtip_webhook.name
    repeat_interval = "4h"
    continue        = true
  }

  dynamic "policy" {
    for_each = local._slack_enabled ? [1] : []
    content {
      matcher {
        label = "severity"
        match = "="
        value = "warning"
      }
      contact_point   = grafana_contact_point.slack_alerts[0].name
      repeat_interval = "4h"
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
