variable "cloudflare_api_key" {
  description = "Cloudflare Global API Key"
  type        = string
  sensitive   = true
}

variable "cloudflare_email" {
  description = "Cloudflare account email address"
  type        = string
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID"
  type        = string
}

variable "cloudflare_secrets_store_id" {
  description = "Existing Cloudflare Secrets Store ID"
  type        = string
  default     = "88dc5de305594f08aeb9bc04dad2f8cf"
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
}

variable "synology_domain" {
  description = "Domain/subdomain for Synology proxy (e.g., nas.jclee.me)"
  type        = string
}

variable "synology_nas_ip" {
  description = "Synology NAS IP address on local network"
  type        = string
  default     = "192.168.50.215"
}

variable "synology_nas_port" {
  description = "Synology DSM HTTPS port"
  type        = number
  default     = 5001
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
}

# ============================================
# Homelab Tunnel Variables
# ============================================

variable "homelab_domain" {
  description = "Base domain for homelab services"
  type        = string
  default     = "jclee.me"
}

variable "traefik_ip" {
  description = "Traefik reverse proxy IP (entry point for all homelab services)"
  type        = string
  default     = "192.168.50.102"
}
