variable "grafana_url" {
  description = "Grafana instance URL"
  type        = string
  default     = "http://192.168.50.104:3000"
}

variable "grafana_auth" {
  description = "Grafana API key or service account token"
  type        = string
  sensitive   = true
}

variable "n8n_webhook_url" {
  description = "n8n webhook URL for alert notifications"
  type        = string
  sensitive   = true
}
