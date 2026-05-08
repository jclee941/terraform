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

variable "enable_gcp" {
  description = "Whether to look up GCP secrets from 1Password (requires 'gcp' item in vault)"
  type        = bool
  default     = false
}

variable "enable_registry" {
  description = "Whether to look up Docker Registry (MinIO) secrets from 1Password (requires 'registry' item in vault)"
  type        = bool
  default     = false
}
