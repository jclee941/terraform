output "host_inventory_loaded" {
  description = "Whether the host inventory was successfully loaded from remote state"
  value       = length(local.hosts) > 0
}
