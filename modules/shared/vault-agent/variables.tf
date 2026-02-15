variable "service_name" {
  description = "Service identifier used for Vault role and policy naming"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,62}$", var.service_name))
    error_message = "service_name must be lowercase alphanumeric with hyphens, starting with a letter (max 63 chars)."
  }
}

variable "vault_addr" {
  description = "Vault server address"
  type        = string
  default     = "https://vault.jclee.me"

  validation {
    condition     = can(regex("^https?://", var.vault_addr))
    error_message = "vault_addr must be a valid HTTP(S) URL."
  }
}

variable "vault_mount" {
  description = "Vault KV v2 mount path"
  type        = string
  default     = "secret"

  validation {
    condition     = length(var.vault_mount) > 0
    error_message = "vault_mount must not be empty."
  }
}

variable "kv_path" {
  description = "KV secret path under the mount (e.g. homelab/mcphub)"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9/_-]+$", var.kv_path))
    error_message = "kv_path must contain only alphanumeric characters, slashes, hyphens, and underscores."
  }
}

variable "approle_backend_path" {
  description = "Path of the AppRole auth backend"
  type        = string
  default     = "approle"

  validation {
    condition     = length(var.approle_backend_path) > 0
    error_message = "approle_backend_path must not be empty."
  }
}

variable "create_approle_backend" {
  description = "Whether to create the AppRole auth backend (set false if it already exists)"
  type        = bool
  default     = false
}

variable "token_ttl" {
  description = "Default TTL for tokens issued by this role"
  type        = number
  default     = 3600

  validation {
    condition     = var.token_ttl > 0
    error_message = "token_ttl must be a positive number (seconds)."
  }
}

variable "token_max_ttl" {
  description = "Maximum TTL for tokens issued by this role"
  type        = number
  default     = 14400

  validation {
    condition     = var.token_max_ttl > 0
    error_message = "token_max_ttl must be a positive number (seconds)."
  }
}

variable "additional_kv_paths" {
  description = "Additional KV secret paths this agent needs read access to"
  type        = list(string)
  default     = []
}

variable "template_mappings" {
  description = "Map of Vault Agent template source to destination paths"
  type = map(object({
    source      = string
    destination = string
    perms       = optional(string, "0640")
  }))
  default = {}
}
