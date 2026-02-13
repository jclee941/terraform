output "hosts" {
  description = "Pass-through of host inventory"
  value       = var.hosts
}

output "network" {
  description = "Network configuration"
  value       = var.network
}

output "template_vars" {
  description = "Variables for rendering config templates"
  value       = local.template_vars
}

output "infrastructure_nodes" {
  description = "Infrastructure node list for Prometheus"
  value       = local.infrastructure_nodes
}
