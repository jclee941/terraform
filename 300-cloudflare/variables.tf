

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

  validation {
    condition     = var.github_token == "" || can(regex("^(ghp_|github_pat_)", var.github_token))
    error_message = "github_token must be empty or start with 'ghp_' (classic) or 'github_pat_' (fine-grained)."
  }
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

  validation {
    condition     = length(var.access_allowed_emails) > 0
    error_message = "access_allowed_emails must contain at least one email address."
  }

  validation {
    condition     = alltrue([for email in var.access_allowed_emails : can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", email))])
    error_message = "All entries in access_allowed_emails must be valid email addresses."
  }
}

variable "google_oauth_client_id" {
  description = "Google OAuth 2.0 Client ID for CF Access IdP (optional if provided via 1Password)"
  type        = string
  default     = ""
}

variable "google_oauth_client_secret" {
  description = "Google OAuth 2.0 Client Secret for CF Access IdP (optional if provided via 1Password)"
  type        = string
  sensitive   = true
  default     = ""
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


# ============================================
# Homelab host IP variables
# ============================================

variable "jclee_ip" {
  description = "JCLee workstation IP address (physical PC, host ID 80)"
  type        = string
  default     = "192.168.50.80"

  validation {
    condition     = can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", var.jclee_ip))
    error_message = "jclee_ip must be a valid IPv4 address."
  }
}

variable "jclee_dev_ip" {
  description = "JCLee development workstation IP address (VMID 200)"
  type        = string
  default     = "192.168.50.200"

  validation {
    condition     = can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", var.jclee_dev_ip))
    error_message = "jclee_dev_ip must be a valid IPv4 address."
  }
}

variable "elk_ip" {
  description = "ELK stack IP address (VMID 105)"
  type        = string
  default     = "192.168.50.105"

  validation {
    condition     = can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", var.elk_ip))
    error_message = "elk_ip must be a valid IPv4 address."
  }
}

variable "youtube_ip" {
  description = "YouTube media server IP address (VMID 220)"
  type        = string
  default     = "192.168.50.220"

  validation {
    condition     = can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", var.youtube_ip))
    error_message = "youtube_ip must be a valid IPv4 address."
  }
}
