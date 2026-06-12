output "homelab_tunnel_id" {
  description = "Cloudflare Tunnel ID for homelab services"
  value       = module.tunnels["homelab"].tunnel_id
  sensitive   = true
}

output "homelab_tunnel_token" {
  description = "Cloudflare Tunnel token for homelab cloudflared connector"
  value       = module.tunnels["homelab"].tunnel_token
  sensitive   = true
}

output "homelab_dns_records" {
  description = "DNS records created for homelab services"
  value = {
    for key, record in cloudflare_dns_record.homelab :
    key => record.name
  }
}
