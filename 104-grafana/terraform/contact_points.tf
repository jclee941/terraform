resource "grafana_contact_point" "alert_log_fallback" {
  name = "alert-log-fallback"

  webhook {
    url = "${var.grafana_url}/api/alertmanager/grafana/api/v2/alerts"
  }
}

resource "grafana_contact_point" "slack_alerts" {
  count = local._slack_enabled ? 1 : 0
  name  = "slack-alerts"

  slack {
    url   = local.effective_slack_webhook_url
    title = "{{ .CommonLabels.alertname }}"
    text  = "{{ .CommonAnnotations.summary }}\n{{ .CommonAnnotations.description }}"
  }
}
