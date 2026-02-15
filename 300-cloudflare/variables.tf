

variable "cloudflare_account_id" {
  description = "Cloudflare account ID"
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{32}$", var.cloudflare_account_id))
    error_message = "cloudflare_account_id must be a 32-character lowercase hex string."
  }
}

variable "cloudflare_secrets_store_id" {
  description = "Existing Cloudflare Secrets Store ID"
  type        = string
  default     = "88dc5de305594f08aeb9bc04dad2f8cf"

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
  description = "GitHub token with actions secret write permissions"
  type        = string
  sensitive   = true
  default     = ""
}

variable "vault_address" {
  description = "Vault server address"
  type        = string
  default     = "http://192.168.50.112:8200"

  validation {
    condition     = can(regex("^https?://", var.vault_address))
    error_message = "vault_address must be a valid HTTP(S) URL."
  }
}

variable "vault_token" {
  description = "Vault token with write access to target mount/path"
  type        = string
  sensitive   = true
  default     = ""
}

variable "vault_mount_path" {
  description = "Vault KV v2 mount path"
  type        = string
  default     = "secret"
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
  description = "Cloudflare zone ID for DNS records and Workers routes"
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{32}$", var.cloudflare_zone_id))
    error_message = "cloudflare_zone_id must be a 32-character lowercase hex string."
  }
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

variable "r2_cache_ttl_days" {
  description = "R2 cache TTL in days for cached Synology files"
  type        = number
  default     = 7

  validation {
    condition     = var.r2_cache_ttl_days > 0
    error_message = "r2_cache_ttl_days must be a positive number."
  }
}

# ============================================
# Homelab Tunnel Variables
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


