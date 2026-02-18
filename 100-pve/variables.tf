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
# Managed Stack VMID Range
# -----------------------------------------------------------------------------

variable "managed_vmid_range" {
  description = "VMID range for Terraform-managed containers (101-112)"
  type = object({
    min = number
    max = number
  })
  default = {
    min = 101
    max = 112
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
