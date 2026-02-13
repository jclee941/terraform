# =============================================================================
# TERRAFORM VARIABLES
# =============================================================================
# This file defines input variables with validation for the Proxmox IaC stack.
# Sensitive values should be passed via environment variables or tfvars.
# =============================================================================

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------

variable "proxmox_endpoint" {
  description = "Proxmox VE API endpoint URL"
  type        = string
  default     = "https://192.168.50.100:8006/"

  validation {
    condition     = can(regex("^https://", var.proxmox_endpoint))
    error_message = "Proxmox endpoint must use HTTPS."
  }
}

variable "proxmox_api_token" {
  description = "Proxmox API token in format 'user@realm!tokenid=uuid'"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[a-zA-Z0-9]+@[a-zA-Z]+![a-zA-Z0-9-]+=", var.proxmox_api_token))
    error_message = "API token must be in format 'user@realm!tokenid=uuid'."
  }
}

variable "proxmox_insecure" {
  description = "Skip TLS verification (use only for self-signed certs)"
  type        = bool
  default     = true
}


# -----------------------------------------------------------------------------
# Infrastructure Configuration
# -----------------------------------------------------------------------------

variable "node_name" {
  description = "Proxmox node name to deploy containers"
  type        = string
  default     = "pve3"

  validation {
    condition     = can(regex("^pve[0-9]+$", var.node_name))
    error_message = "Node name must match pattern 'pveN' (e.g., pve1, pve3)."
  }
}

variable "network_gateway" {
  description = "Network gateway IP address"
  type        = string
  default     = "192.168.50.1"

  validation {
    condition     = can(cidrhost("${var.network_gateway}/24", 0))
    error_message = "Must be a valid IPv4 address."
  }
}

variable "network_cidr" {
  description = "Network CIDR for container IPs"
  type        = string
  default     = "192.168.50.0/24"

  validation {
    condition     = can(cidrsubnet(var.network_cidr, 0, 0))
    error_message = "Must be a valid CIDR notation (e.g., 192.168.50.0/24)."
  }
}

variable "dns_servers" {
  description = "DNS servers for containers"
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]

  validation {
    condition     = length(var.dns_servers) > 0 && length(var.dns_servers) <= 3
    error_message = "Must specify 1-3 DNS servers."
  }
}

variable "datastore_id" {
  description = "Proxmox storage ID for container disks"
  type        = string
  default     = "dfge"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_-]*$", var.datastore_id))
    error_message = "Datastore ID must start with a letter and contain only alphanumeric characters, hyphens, or underscores."
  }
}

# -----------------------------------------------------------------------------
# Container Defaults
# -----------------------------------------------------------------------------

variable "default_swap" {
  description = "Default swap memory in MB for containers"
  type        = number
  default     = 512

  validation {
    condition     = var.default_swap >= 0 && var.default_swap <= 8192
    error_message = "Swap must be between 0 and 8192 MB."
  }
}

variable "container_defaults" {
  description = "Default values for container resources"
  type = object({
    memory    = number
    cores     = number
    disk_size = number
  })
  default = {
    memory    = 1024
    cores     = 1
    disk_size = 10
  }

  validation {
    condition     = var.container_defaults.memory >= 256 && var.container_defaults.memory <= 65536
    error_message = "Memory must be between 256 MB and 64 GB."
  }

  validation {
    condition     = var.container_defaults.cores >= 1 && var.container_defaults.cores <= 16
    error_message = "Cores must be between 1 and 16."
  }

  validation {
    condition     = var.container_defaults.disk_size >= 4 && var.container_defaults.disk_size <= 500
    error_message = "Disk size must be between 4 and 500 GB."
  }
}

# -----------------------------------------------------------------------------
# Container Specifications (Override per-container)
# -----------------------------------------------------------------------------

variable "container_overrides" {
  description = "Per-container resource overrides"
  type = map(object({
    memory      = optional(number)
    cores       = optional(number)
    disk_size   = optional(number)
    privileged  = optional(bool, false)
    description = optional(string)
  }))
  default = {}

  # Validation for any overridden memory values
  validation {
    condition = alltrue([
      for k, v in var.container_overrides :
      v.memory == null || (v.memory >= 256 && v.memory <= 65536)
    ])
    error_message = "Container memory overrides must be between 256 MB and 64 GB."
  }

  # Validation for any overridden cores values
  validation {
    condition = alltrue([
      for k, v in var.container_overrides :
      v.cores == null || (v.cores >= 1 && v.cores <= 16)
    ])
    error_message = "Container cores overrides must be between 1 and 16."
  }

  # Validation for any overridden disk_size values
  validation {
    condition = alltrue([
      for k, v in var.container_overrides :
      v.disk_size == null || (v.disk_size >= 4 && v.disk_size <= 500)
    ])
    error_message = "Container disk_size overrides must be between 4 and 500 GB."
  }
}

# -----------------------------------------------------------------------------
# Managed Stack VMID Range
# -----------------------------------------------------------------------------

variable "managed_vmid_range" {
  description = "VMID range for Terraform-managed containers (101-113)"
  type = object({
    min = number
    max = number
  })
  default = {
    min = 101
    max = 113
  }

  validation {
    condition     = var.managed_vmid_range.min < var.managed_vmid_range.max
    error_message = "Min VMID must be less than max VMID."
  }

  validation {
    condition     = var.managed_vmid_range.min >= 100 && var.managed_vmid_range.max <= 199
    error_message = "VMID range must be within 100-199 for this infrastructure."
  }
}

# -----------------------------------------------------------------------------
# SSH Configuration
# -----------------------------------------------------------------------------

variable "ssh_public_keys" {
  description = "SSH public keys for LXC containers (root user)"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for key in var.ssh_public_keys :
      can(regex("^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp(256|384|521)|sk-ssh-ed25519@openssh\\.com|sk-ecdsa-sha2-nistp256@openssh\\.com)\\s+[A-Za-z0-9+/=]+", key))
    ])
    error_message = "Each SSH public key must be in a valid format (ssh-rsa, ssh-ed25519, or ecdsa-sha2-nistp*)."
  }
}

variable "deploy_mcp_configs" {
  description = "Whether to deploy MCP configurations to remote hosts via SSH"
  type        = bool
  default     = false
}

variable "deploy_vm_configs" {
  description = "Whether to deploy VM configurations via SSH"
  type        = bool
  default     = false
}

variable "deploy_lxc_configs" {
  description = "Whether to deploy LXC configurations via SSH"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Vault Configuration
# -----------------------------------------------------------------------------

variable "vault_address" {
  description = "HashiCorp Vault server address"
  type        = string
  default     = "http://192.168.50.112:8200"

  validation {
    condition     = can(regex("^https?://", var.vault_address))
    error_message = "Vault address must start with http:// or https://."
  }
}

variable "vault_token" {
  description = "Vault authentication token (use terraform-readonly policy)"
  type        = string
  sensitive   = true
}
