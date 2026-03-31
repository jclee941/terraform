# ============================================
# JCLee Workstation Tunnel Outputs
# ============================================

output "jclee_tunnel_id" {
  description = "Cloudflare Tunnel ID for JCLee workstation"
  value       = cloudflare_zero_trust_tunnel_cloudflared.jclee.id
  sensitive   = true
}

output "jclee_tunnel_token" {
  description = "Cloudflare Tunnel token for JCLee cloudflared connector"
  value       = data.cloudflare_zero_trust_tunnel_cloudflared_token.jclee.token
  sensitive   = true
}
