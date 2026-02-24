# ============================================
# Synology Integration Outputs
# ============================================

output "tunnel_id" {
  description = "Cloudflare Tunnel ID for Synology NAS"
  value       = cloudflare_zero_trust_tunnel_cloudflared.synology.id
  sensitive   = true
}

output "tunnel_token" {
  description = "Cloudflare Tunnel token for cloudflared runtime"
  value       = data.cloudflare_zero_trust_tunnel_cloudflared_token.synology.token
  sensitive   = true
}

output "synology_domain" {
  description = "Synology domain protected by Cloudflare Access"
  value       = var.synology_domain
}

output "r2_bucket_name" {
  description = "R2 bucket name used for Synology cache"
  value       = cloudflare_r2_bucket.synology_cache.name
}

output "access_application_id" {
  description = "Cloudflare Access application ID for Synology"
  value       = cloudflare_zero_trust_access_application.synology.id
}
