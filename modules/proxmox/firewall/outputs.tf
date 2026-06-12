output "container_ids" {
  description = "Container target IDs keyed by guest name when target_kind is container."
  value       = var.target_kind == "container" ? { for name, target in var.targets : name => target.vmid } : {}
}

output "vm_ids" {
  description = "VM target IDs keyed by guest name when target_kind is vm."
  value       = var.target_kind == "vm" ? { for name, target in var.targets : name => target.vmid } : {}
}

output "rule_counts" {
  description = "Total firewall rule count per target, including common egress rules."
  value       = { for name, target in var.targets : name => length(target.rules) + length(var.egress_rules) }
}
