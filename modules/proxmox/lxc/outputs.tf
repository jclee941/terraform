output "vmid" {
  description = "Container VMID"
  value       = proxmox_virtual_environment_container.this.vm_id
}

output "ip_address" {
  description = "Container IP address"
  value       = var.ip_address
}

output "status" {
  description = "Container status summary"
  value = {
    started = proxmox_virtual_environment_container.this.started
    node    = proxmox_virtual_environment_container.this.node_name
  }
}
