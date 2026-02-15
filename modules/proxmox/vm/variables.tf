variable "node_name" {
  description = "Proxmox node name"
  type        = string

  validation {
    condition     = length(var.node_name) > 0
    error_message = "node_name must not be empty."
  }
}

variable "vmid" {
  description = "VM ID"
  type        = number

  validation {
    condition     = var.vmid >= 100 && var.vmid <= 999
    error_message = "vmid must be between 100 and 999."
  }
}

variable "hostname" {
  description = "VM hostname"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,62}$", var.hostname))
    error_message = "hostname must be a valid DNS label (lowercase, starts with letter, max 63 chars)."
  }
}

variable "ip_address" {
  description = "VM IPv4 address (without CIDR)"
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
    condition     = var.memory >= 512 && var.memory <= 65536
    error_message = "memory must be between 512 MB and 65536 MB."
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
    condition     = var.disk_size >= 8 && var.disk_size <= 500
    error_message = "disk_size must be between 8 GB and 500 GB."
  }
}

variable "description" {
  description = "VM description"
  type        = string
}

variable "network_gateway" {
  description = "Network gateway IP"
  type        = string

  validation {
    condition     = can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", var.network_gateway))
    error_message = "network_gateway must be a valid IPv4 address."
  }
}

variable "dns_servers" {
  description = "DNS servers"
  type        = list(string)

  validation {
    condition     = length(var.dns_servers) > 0
    error_message = "dns_servers must contain at least one entry."
  }
}

variable "datastore_id" {
  description = "Proxmox storage ID for VM disks"
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

variable "clone_template_id" {
  description = "Template VMID to clone from"
  type        = number
  default     = 9000
}

variable "bios" {
  description = "BIOS type (seabios or ovmf)"
  type        = string
  default     = "seabios"

  validation {
    condition     = contains(["seabios", "ovmf"], var.bios)
    error_message = "bios must be 'seabios' or 'ovmf'."
  }
}

variable "machine" {
  description = "Machine type (pc or q35)"
  type        = string
  default     = "pc"

  validation {
    condition     = contains(["pc", "q35"], var.machine)
    error_message = "machine must be 'pc' or 'q35'."
  }
}

variable "cpu_type" {
  description = "CPU type"
  type        = string
  default     = "host"
}

variable "disk_interface" {
  description = "Disk interface (scsi0, virtio0, etc.)"
  type        = string
  default     = "scsi0"

  validation {
    condition     = can(regex("^(scsi|virtio|sata|ide)\\d+$", var.disk_interface))
    error_message = "disk_interface must match pattern like scsi0, virtio0, sata0, ide0."
  }
}

variable "cloud_init_datastore_id" {
  description = "Datastore for cloud-init drive"
  type        = string
  default     = "local"
}

variable "cloud_init_file_id" {
  description = "Cloud-init user-data snippet file ID"
  type        = string
  default     = null
}

variable "on_boot" {
  description = "Start VM on host boot"
  type        = bool
  default     = true
}
