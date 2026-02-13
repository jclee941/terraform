output "container_ip" {
  description = "Traefik container IP address"
  value       = module.lxc.ip_address
}

output "container_id" {
  description = "Traefik container VMID"
  value       = module.lxc.vmid
}
