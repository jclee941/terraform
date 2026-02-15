variable "service_name" {
  description = "Service identifier used for Vault role and policy naming"
  type        = string
}

variable "vault_addr" {
  description = "Vault server address"
  type        = string
  default     = "https://vault.jclee.me"
}

variable "vault_mount" {
  description = "Vault KV v2 mount path"
  type        = string
  default     = "secret"
}

variable "kv_path" {
  description = "KV secret path under the mount (e.g. homelab/mcphub)"
  type        = string
}

variable "approle_backend_path" {
  description = "Path of the AppRole auth backend"
  type        = string
  default     = "approle"
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
}

variable "token_max_ttl" {
  description = "Maximum TTL for tokens issued by this role"
  type        = number
  default     = 14400
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
