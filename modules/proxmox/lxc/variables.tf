variable "node_name" {
  description = "Proxmox node name to deploy the container"
  type        = string

  validation {
    condition     = length(var.node_name) > 0
    error_message = "node_name must not be empty."
  }
}

variable "vmid" {
  description = "Container VMID"
  type        = number

  validation {
    condition     = var.vmid >= 100 && var.vmid <= 999
    error_message = "vmid must be between 100 and 999."
  }
}

variable "hostname" {
  description = "Container hostname"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,62}$", var.hostname))
    error_message = "hostname must be a valid DNS label (lowercase, starts with letter, max 63 chars)."
  }
}

variable "ip_address" {
  description = "Container IPv4 address (without CIDR)"
  type        = string

  validation {
    condition     = can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", var.ip_address))
    error_message = "ip_address must be a valid IPv4 address without CIDR."
  }
}

variable "memory" {
  description = "Dedicated memory in MB"
  type        = number

  validation {
    condition     = var.memory >= 128 && var.memory <= 65536
    error_message = "memory must be between 128 MB and 65536 MB."
  }
}

variable "cores" {
  description = "CPU cores"
  type        = number

  validation {
    condition     = var.cores >= 1 && var.cores <= 16
    error_message = "cores must be between 1 and 16."
  }
}

variable "disk_size" {
  description = "Disk size in GB"
  type        = number

  validation {
    condition     = var.disk_size >= 2 && var.disk_size <= 500
    error_message = "disk_size must be between 2 GB and 500 GB."
  }
}

variable "description" {
  description = "Container description"
  type        = string
}

variable "privileged" {
  description = "Run container in privileged mode"
  type        = bool
  default     = false
}

variable "network_gateway" {
  description = "Network gateway IP address"
  type        = string

  validation {
    condition     = can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", var.network_gateway))
    error_message = "network_gateway must be a valid IPv4 address."
  }
}

variable "dns_servers" {
  description = "DNS servers for containers"
  type        = list(string)

  validation {
    condition     = length(var.dns_servers) > 0
    error_message = "dns_servers must contain at least one entry."
  }
}

variable "swap" {
  description = "Swap memory in MB (per-container)"
  type        = number
  default     = 512

  validation {
    condition     = var.swap >= 0 && var.swap <= 16384
    error_message = "swap must be between 0 MB and 16384 MB."
  }
}

variable "datastore_id" {
  description = "Proxmox storage ID for container disks"
  type        = string

  validation {
    condition     = length(var.datastore_id) > 0
    error_message = "datastore_id must not be empty."
  }
}

variable "managed_vmid_min" {
  description = "Minimum managed VMID"
  type        = number

  validation {
    condition     = var.managed_vmid_min >= 100
    error_message = "managed_vmid_min must be >= 100."
  }
}

variable "managed_vmid_max" {
  description = "Maximum managed VMID"
  type        = number

  validation {
    condition     = var.managed_vmid_max <= 999
    error_message = "managed_vmid_max must be <= 999."
  }
}

variable "ssh_public_keys" {
  description = "SSH public keys for root user"
  type        = list(string)
  default     = []
}

variable "template_file_id" {
  description = "Container template file ID (e.g., local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst)"
  type        = string
  default     = "local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst"

  validation {
    condition     = can(regex("^[a-z].*:vztmpl/", var.template_file_id))
    error_message = "template_file_id must match format 'storage:vztmpl/...'."
  }
}


variable "mount_points" {
  description = "List of mount points to add to the container"
  type = list(object({
    volume = string
    path   = string
  }))
  default = []

  validation {
    condition = alltrue([
      for mp in var.mount_points : length(mp.volume) > 0 && length(mp.path) > 0
    ])
    error_message = "Each mount point must have a non-empty volume and path."
  }
}
