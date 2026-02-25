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

variable "n8n_webhook_url" {
  description = "n8n webhook URL for alert notifications"
  type        = string
  default     = "http://192.168.50.112:5678/webhook/grafana-alert"

  validation {
    condition     = can(regex("^https?://", var.n8n_webhook_url))
    error_message = "n8n_webhook_url must be a valid HTTP(S) URL."
  }
}

variable "n8n_glitchtip_webhook_url" {
  description = "n8n webhook URL for forwarding alerts to GlitchTip"
  type        = string
  default     = "http://192.168.50.112:5678/webhook/grafana-to-glitchtip"

  validation {
    condition     = can(regex("^https?://", var.n8n_glitchtip_webhook_url))
    error_message = "n8n_glitchtip_webhook_url must be a valid HTTP(S) URL."
  }
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
