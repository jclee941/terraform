

variable "cloudflare_account_id" {
  description = "Cloudflare account ID (optional if provided via 1Password)"
  type        = string
  default     = ""
}

variable "cloudflare_secrets_store_id" {
  description = "Existing Cloudflare Secrets Store ID"
  type        = string
  default     = "88dc5de305594f08aeb9bc04dad2f8cf" # pragma: allowlist secret

  validation {
    condition     = can(regex("^[0-9a-f]{32}$", var.cloudflare_secrets_store_id))
    error_message = "cloudflare_secrets_store_id must be a 32-character lowercase hex string."
  }
}

variable "github_owner" {
  description = "GitHub organization/user owner"
  type        = string
  default     = "qws941"
}

variable "github_token" {
  description = "GitHub token with actions secret write permissions (optional if provided via 1Password)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "op_service_account_token" {
  description = "1Password service account token"
  type        = string
  sensitive   = true
  default     = ""
}

variable "onepassword_vault_name" {
  description = "1Password vault name for secret lookups"
  type        = string
  default     = "homelab"
}

variable "secret_values" {
  description = "Runtime secret values map, keyed by secret name (never commit)"
  type        = map(string)
  sensitive   = true
  default     = {}
}

variable "enable_cf_store_sync" {
  description = "Enable local-exec wrangler sync for CF Secrets Store beta workflow"
  type        = bool
  default     = false
}

# ============================================
# Synology NAS Integration Variables
# ============================================

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for DNS records and Workers routes (optional if provided via 1Password)"
  type        = string
  default     = ""
}

variable "synology_domain" {
  description = "Domain/subdomain for Synology proxy (e.g., nas.jclee.me)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]+[a-z0-9]$", var.synology_domain))
    error_message = "synology_domain must be a valid domain name."
  }
}

variable "synology_nas_ip" {
  description = "Synology NAS IP address on local network"
  type        = string
  default     = "192.168.50.215"

  validation {
    condition     = can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", var.synology_nas_ip))
    error_message = "synology_nas_ip must be a valid IPv4 address."
  }
}

variable "synology_nas_port" {
  description = "Synology DSM HTTPS port"
  type        = number
  default     = 5001

  validation {
    condition     = var.synology_nas_port >= 1 && var.synology_nas_port <= 65535
    error_message = "synology_nas_port must be between 1 and 65535."
  }
}

variable "access_allowed_emails" {
  description = "List of email addresses allowed through CF Access"
  type        = list(string)
}

variable "enable_worker_route" {
  description = "Enable Workers route (set to true after Worker is deployed via wrangler)"
  type        = bool
  default     = false
}


# ============================================
# homelab tunnel variables
# ============================================

variable "homelab_domain" {
  description = "Base domain for homelab services"
  type        = string
  default     = "jclee.me"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]+[a-z0-9]$", var.homelab_domain))
    error_message = "homelab_domain must be a valid domain name."
  }
}
