# -----------------------------------------------------------------------------
# 1Password
# -----------------------------------------------------------------------------

variable "onepassword_vault_name" {
  description = "1Password vault name for secret retrieval"
  type        = string
  default     = "homelab"

  validation {
    condition     = length(var.onepassword_vault_name) > 0
    error_message = "vault name must not be empty"
  }
}

# -----------------------------------------------------------------------------
# Synology DSM
# -----------------------------------------------------------------------------

variable "synology_host" {
  description = "Synology DSM HTTPS URL (e.g. https://192.168.50.215:5001)"
  type        = string
  default     = "https://192.168.50.215:5001"

  validation {
    condition     = can(regex("^https://", var.synology_host))
    error_message = "synology_host must start with https://"
  }
}

variable "synology_user" {
  description = "Synology DSM admin username (overridden by 1Password if available)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "synology_password" {
  description = "Synology DSM admin password (overridden by 1Password if available)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "synology_skip_cert_check" {
  description = "Skip TLS certificate verification for self-signed DSM certs"
  type        = bool
  default     = true
}
