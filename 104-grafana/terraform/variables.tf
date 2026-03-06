variable "grafana_url" {
  description = "Grafana instance URL"
  type        = string
  default     = "http://192.168.50.104:3000"

  validation {
    condition     = can(regex("^https?://", var.grafana_url))
    error_message = "grafana_url must be a valid HTTP(S) URL."
  }
}

variable "grafana_auth" {
  description = "Grafana API key or service account token"
  type        = string
  sensitive   = true
  default     = ""
}

variable "grafana_admin_username" {
  description = "Grafana admin username used for basic auth fallback"
  type        = string
  default     = "admin"
}

variable "grafana_admin_password" {
  description = "Grafana admin password used for basic auth fallback (overrides 1Password if set)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "slack_webhook_url" {
  description = "Slack incoming webhook URL for alert notifications (fallback if not in 1Password)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "onepassword_vault_name" {
  description = "1Password vault name for secret lookups"
  type        = string
  default     = "homelab"

  validation {
    condition     = length(var.onepassword_vault_name) > 0
    error_message = "onepassword_vault_name must not be empty."
  }
}
