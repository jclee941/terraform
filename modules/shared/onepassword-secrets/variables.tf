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

variable "enable_synology" {
  description = "Whether to look up Synology secrets from 1Password (requires 'synology' item in vault)"
  type        = bool
  default     = false
}

variable "enable_youtube" {
  description = "Whether to look up YouTube secrets from 1Password (requires 'youtube' item in vault)"
  type        = bool
  default     = false
}
