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

variable "balloon_min" {
  description = "Balloon minimum memory in MB (0 = balloon disabled)"
  type        = number
  default     = 0

  validation {
    condition     = var.balloon_min >= 0 && var.balloon_min <= var.memory
    error_message = "balloon_min must be >= 0 and <= memory."
  }
}

variable "ssd_emulation" {
  description = "Enable SSD emulation (TRIM support via guest OS)"
  type        = bool
  default     = true
}

variable "disk_discard" {
  description = "Disk discard mode (on or ignore)"
  type        = string
  default     = "on"

  validation {
    condition     = contains(["on", "ignore"], var.disk_discard)
    error_message = "disk_discard must be 'on' or 'ignore'."
  }
}

variable "disk_aio" {
  description = "Disk async IO mode (io_uring, native, or threads)"
  type        = string
  default     = "io_uring"

  validation {
    condition     = contains(["io_uring", "native", "threads"], var.disk_aio)
    error_message = "disk_aio must be 'io_uring', 'native', or 'threads'."
  }
}

variable "disk_backup" {
  description = "Include VM disk in Proxmox backups (null = provider default)"
  type        = bool
  default     = null
}

variable "disk_cache" {
  description = "Disk cache mode (null = provider default)"
  type        = string
  default     = null
}

variable "disk_replicate" {
  description = "Include VM disk in replication jobs (null = provider default)"
  type        = bool
  default     = null
}

variable "cores" {
  description = "CPU cores"
  type        = number

  validation {
    condition     = var.cores >= 1 && var.cores <= 16
    error_message = "cores must be between 1 and 16."
  }
}

variable "cpu_limit" {
  description = "CPU usage limit in cores (null = Proxmox default/no explicit limit)"
  type        = number
  default     = null

  validation {
    condition     = var.cpu_limit == null || var.cpu_limit >= 0
    error_message = "cpu_limit must be null or >= 0."
  }
}

variable "cpu_units" {
  description = "CPU scheduler weight (null = Proxmox default)"
  type        = number
  default     = null

  validation {
    condition     = var.cpu_units == null || (var.cpu_units >= 1 && var.cpu_units <= 10000)
    error_message = "cpu_units must be null or between 1 and 10000."
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

variable "cpu_numa" {
  description = "Enable NUMA CPU topology"
  type        = bool
  default     = false
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

variable "started" {
  description = "Keep VM started"
  type        = bool
  default     = true
}

variable "protection" {
  description = "Protect VM and disks from removal"
  type        = bool
  default     = true
}

variable "hotplug" {
  description = "VM hotplug feature list, or 0 to disable"
  type        = string
  default     = null
}

variable "keyboard_layout" {
  description = "VM keyboard layout (null = provider default)"
  type        = string
  default     = null
}

variable "tablet_device" {
  description = "Enable USB tablet device"
  type        = bool
  default     = false
}

variable "scsi_hardware" {
  description = "SCSI controller model"
  type        = string
  default     = "virtio-scsi-single"
}

variable "vga_type" {
  description = "VGA type"
  type        = string
  default     = "std"
}

variable "vga_memory" {
  description = "VGA memory in MB (null = provider default)"
  type        = number
  default     = 16
}

variable "vga_clipboard" {
  description = "VGA clipboard mode (null = disabled/provider default)"
  type        = string
  default     = null
}

variable "efi_pre_enrolled_keys" {
  description = "Use pre-enrolled EFI secure boot keys for OVMF VMs"
  type        = bool
  default     = false
}


variable "hostpci_devices" {
  description = "PCI devices to pass through to the VM (use 'mapping' for resource-mapped devices, 'id' for raw passthrough)"
  type = list(object({
    device   = string
    mapping  = optional(string)
    id       = optional(string)
    mdev     = optional(string)
    pcie     = optional(bool, true)
    rom_file = optional(string)
    rombar   = optional(bool)
    xvga     = optional(bool)
  }))
  default = []
}

variable "usb_devices" {
  description = "USB devices to pass through to the VM"
  type = list(object({
    host = string
    usb3 = optional(bool, false)
  }))
  default = []
}

variable "qemu_agent_trim" {
  description = "Enable fstrim on cloned disks via QEMU agent"
  type        = bool
  default     = true
}

variable "qemu_agent_type" {
  description = "QEMU agent interface type"
  type        = string
  default     = "virtio"
}

variable "serial_devices" {
  description = "Serial devices to attach to the VM"
  type = list(object({
    device = optional(string, "socket")
  }))
  default = []
}
