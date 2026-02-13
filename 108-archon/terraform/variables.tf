variable "proxmox_endpoint" {
  description = "Proxmox API endpoint"
  type        = string
  default     = "https://192.168.50.100:8006"
}

variable "proxmox_api_token" {
  description = "Proxmox API token"
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
  default     = "pve"
}

variable "network_gateway" {
  description = "Network gateway IP"
  type        = string
  default     = "192.168.50.1"
}

variable "dns_servers" {
  description = "DNS servers"
  type        = list(string)
  default     = ["192.168.50.1"]
}

variable "datastore_id" {
  description = "Proxmox storage datastore"
  type        = string
  default     = "local-zfs"
}

variable "ssh_public_keys" {
  description = "SSH public keys for root access"
  type        = list(string)
  default     = []
}

variable "deploy_lxc_configs" {
  description = "Deploy LXC configs via SSH"
  type        = bool
  default     = false
}

variable "supabase_url" {
  description = "Supabase project URL (from Vault)"
  type        = string
  sensitive   = true
}

variable "supabase_service_key" {
  description = "Supabase service role key (from Vault)"
  type        = string
  sensitive   = true
}
