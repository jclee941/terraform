output "homelab_tunnel_id" {
  description = "Cloudflare Tunnel ID for homelab services"
  value       = cloudflare_zero_trust_tunnel_cloudflared.homelab.id
  sensitive   = true
}

output "homelab_tunnel_token" {
  description = "Cloudflare Tunnel token for homelab cloudflared connector"
  value       = data.cloudflare_zero_trust_tunnel_cloudflared_token.homelab.token
  sensitive   = true
}

output "homelab_dns_records" {
  description = "DNS records created for homelab services"
  value = {
    for key, record in cloudflare_dns_record.homelab :
    key => record.name
  }
}

output "homelab_access_applications" {
  description = "Cloudflare Access applications for restricted services"
  value = {
    for key, app in cloudflare_zero_trust_access_application.homelab :
    key => app.domain
  }
}
