output "vmid" {
  description = "VM ID"
  value       = proxmox_virtual_environment_vm.this.vm_id
}

output "ip_address" {
  description = "VM IP address"
  value       = var.ip_address
}

output "status" {
  description = "VM status summary"
  value = {
    started = proxmox_virtual_environment_vm.this.started
    node    = proxmox_virtual_environment_vm.this.node_name
  }
}
