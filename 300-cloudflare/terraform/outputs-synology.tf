# ============================================
# Synology Integration Outputs
# ============================================

output "tunnel_id" {
  description = "Cloudflare Tunnel ID for Synology NAS"
  value       = module.tunnels["synology"].tunnel_id
  sensitive   = true
}

output "tunnel_token" {
  description = "Cloudflare Tunnel token for cloudflared runtime"
  value       = module.tunnels["synology"].tunnel_token
  sensitive   = true
}

output "tunnels" {
  description = "Cloudflare tunnel IDs and tokens by tunnel key."
  value = {
    for key, tunnel in module.tunnels : key => {
      id    = tunnel.tunnel_id
      token = tunnel.tunnel_token
    }
  }
  sensitive = true
}

output "synology_domain" {
  description = "Synology domain protected by Cloudflare Access"
  value       = var.synology_domain
}

output "r2_bucket_name" {
  description = "R2 bucket name used for Synology cache"
  value       = cloudflare_r2_bucket.synology_cache.name
}
