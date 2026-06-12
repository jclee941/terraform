output "tunnel_id" {
  description = "Cloudflare tunnel ID."
  value       = cloudflare_zero_trust_tunnel_cloudflared.this.id
}

output "tunnel_token" {
  description = "Cloudflare tunnel token for cloudflared."
  value       = data.cloudflare_zero_trust_tunnel_cloudflared_token.this.token
  sensitive   = true
}
