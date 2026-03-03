variable "vault_name" {
  description = "1Password vault name containing homelab secrets"
  type        = string
  default     = "homelab"
}

variable "enable_pbs" {
  description = "Whether to look up PBS secrets from 1Password (requires 'pbs' item in vault)"
  type        = bool
  default     = false
}
