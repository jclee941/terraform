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

variable "enable_gcp_lookup" {
  description = "Whether to fetch GCP credentials from 1Password (requires a 'gcp' item)"
  type        = bool
  default     = false
}

variable "gcp_project" {
  description = "GCP project ID override. Falls back to 1Password."
  type        = string
  default     = ""

  validation {
    condition     = var.gcp_project == "" || can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.gcp_project))
    error_message = "gcp_project must be a valid GCP project ID when provided."
  }
}

variable "gcp_region" {
  description = "GCP region for resources."
  type        = string
  default     = "asia-northeast3"

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+$", var.gcp_region))
    error_message = "gcp_region must be a valid GCP region (e.g. us-central1, asia-northeast3)."
  }
}

variable "gcp_credentials" {
  description = "GCP service account key JSON override. Falls back to 1Password."
  type        = string
  default     = ""
  sensitive   = true
}
