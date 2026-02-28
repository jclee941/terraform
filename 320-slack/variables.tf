# =============================================================================
# AUTH VARIABLES
# =============================================================================

variable "onepassword_vault_name" {
  description = "1Password vault name"
  type        = string
  default     = "homelab"

  validation {
    condition     = length(var.onepassword_vault_name) > 0
    error_message = "onepassword_vault_name must not be empty."
  }
}

variable "slack_bot_token" {
  description = "Slack token override (xoxb-*/xoxp-*/xoxe.*). Falls back to 1Password."
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = var.slack_bot_token == "" || can(regex("^xox", var.slack_bot_token))
    error_message = "slack_bot_token must be a valid Slack token (xoxb-/xoxp-/xoxe.) when provided."
  }
}
