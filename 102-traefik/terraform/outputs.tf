output "container_ip" {
  description = "Traefik container IP address"
  value       = local.hosts.traefik.ip
}

output "container_id" {
  description = "Traefik container VMID"
  value       = local.hosts.traefik.vmid
}
