output "container_ip" {
  description = "Traefik container IP address"
  value       = try(local.hosts.traefik.ip, "")
}

output "container_id" {
  description = "Traefik container VMID"
  value       = try(local.hosts.traefik.vmid, null)
}
