variable "node_name" {
  description = "Proxmox node name that owns the firewall targets."
  type        = string
}

variable "targets" {
  description = "Firewall targets keyed by guest name, with VMID and inbound rules."
  type = map(object({
    vmid = number
    rules = list(object({
      dport   = string
      proto   = string
      comment = string
    }))
  }))
}

variable "egress_rules" {
  description = "Common outbound firewall rules applied to every target."
  type = list(object({
    dest    = optional(string)
    proto   = string
    dport   = optional(string)
    comment = string
  }))
}

variable "target_kind" {
  description = "Target type for the Proxmox firewall resources. Determines whether container_id or vm_id is set."
  type        = string

  validation {
    condition     = contains(["container", "vm"], var.target_kind)
    error_message = "target_kind must be either container or vm."
  }
}
