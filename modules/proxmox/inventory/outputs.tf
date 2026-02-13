output "hosts" {
  description = "All infrastructure hosts with IPs and ports"
  value       = local.hosts
}

output "services" {
  description = "Derived service URLs"
  value       = local.services
}

output "prometheus_targets" {
  description = "Node exporter targets for Prometheus"
  value       = local.prometheus_targets
}

output "traefik_backends" {
  description = "Backend services for Traefik routing"
  value       = local.traefik_backends
}
