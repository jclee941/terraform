# =============================================================================
# AUTH VARIABLES
# =============================================================================

variable "op_service_account_token" {
  description = "1Password service account token (set via TF_VAR or env)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "onepassword_vault_name" {
  description = "1Password vault name"
  type        = string
  default     = "homelab"
}

variable "slack_bot_token" {
  description = "Slack bot token override (xoxb-*). Falls back to 1Password."
  type        = string
  default     = ""
  sensitive   = true
}
