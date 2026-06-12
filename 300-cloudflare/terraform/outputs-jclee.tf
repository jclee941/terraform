# ============================================
# JCLee Workstation Tunnel Outputs
# ============================================

output "jclee_tunnel_id" {
  description = "Cloudflare Tunnel ID for JCLee workstation"
  value       = module.tunnels["jclee"].tunnel_id
  sensitive   = true
}

output "jclee_tunnel_token" {
  description = "Cloudflare Tunnel token for JCLee cloudflared connector"
  value       = module.tunnels["jclee"].tunnel_token
  sensitive   = true
}
