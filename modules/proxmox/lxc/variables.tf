variable "node_name" {
  description = "Proxmox node name to deploy the container"
  type        = string
}

variable "vmid" {
  description = "Container VMID"
  type        = number
}

variable "hostname" {
  description = "Container hostname"
  type        = string
}

variable "ip_address" {
  description = "Container IPv4 address (without CIDR)"
  type        = string
}

variable "memory" {
  description = "Dedicated memory in MB"
  type        = number
}

variable "cores" {
  description = "CPU cores"
  type        = number
}

variable "disk_size" {
  description = "Disk size in GB"
  type        = number
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
}

variable "dns_servers" {
  description = "DNS servers for containers"
  type        = list(string)
}

variable "default_swap" {
  description = "Swap memory in MB"
  type        = number
}

variable "datastore_id" {
  description = "Proxmox storage ID for container disks"
  type        = string
}

variable "managed_vmid_min" {
  description = "Minimum managed VMID"
  type        = number
}

variable "managed_vmid_max" {
  description = "Maximum managed VMID"
  type        = number
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
}
