# Tunnel Outputs
output "tunnel_ids" {
  description = "Map of tunnel names to their IDs"
  value = {
    for k, v in cloudflare_zero_trust_tunnel_cloudflared.tunnels :
    k => v.id
  }
}

output "tunnel_tokens" {
  description = "Map of tunnel names to their tokens (sensitive)"
  value = {
    for k, v in cloudflare_zero_trust_tunnel_cloudflared.tunnels :
    k => v.tunnel_token
  }
  sensitive = true
}

output "tunnel_cnames" {
  description = "Map of tunnel names to their CNAME targets"
  value = {
    for k, v in cloudflare_zero_trust_tunnel_cloudflared.tunnels :
    k => "${v.id}.cfargotunnel.com"
  }
}

# Access Application Outputs
output "access_application_ids" {
  description = "Map of access application names to their IDs"
  value = {
    for k, v in cloudflare_zero_trust_access_application.apps :
    k => v.id
  }
}

# R2 Bucket Outputs
output "r2_bucket_names" {
  description = "Map of R2 bucket keys to their names"
  value = {
    for k, v in cloudflare_r2_bucket.buckets :
    k => v.name
  }
}

# Workers Outputs
output "worker_script_names" {
  description = "Map of worker keys to their script names"
  value = {
    for k, v in cloudflare_workers_script.scripts :
    k => v.name
  }
}
