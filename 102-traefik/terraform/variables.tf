variable "proxmox_endpoint" {
  description = "Proxmox VE API endpoint URL"
  type        = string
  default     = "https://192.168.50.100:8006/"
}

variable "proxmox_api_token" {
  description = "Proxmox API token in format user@realm!tokenid=secret"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS verification"
  type        = bool
  default     = true
}

variable "node_name" {
  description = "Proxmox node name"
  type        = string
  default     = "pve3"
}

variable "network_gateway" {
  description = "Network gateway IP address"
  type        = string
  default     = "192.168.50.1"
}

variable "dns_servers" {
  description = "DNS servers for container"
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]
}

variable "datastore_id" {
  description = "Proxmox storage ID for container disk"
  type        = string
  default     = "dfge"
}

variable "ssh_public_keys" {
  description = "SSH public keys for root user"
  type        = list(string)
  default     = []
}

variable "deploy_lxc_configs" {
  description = "Whether to deploy LXC configurations via SSH"
  type        = bool
  default     = false
}
