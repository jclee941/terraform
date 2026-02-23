# ============================================
# DNS records for homelab services
# ============================================

resource "cloudflare_dns_record" "homelab" {
  for_each = local.homelab_services

  zone_id = local.effective_cloudflare_zone_id
  type    = "CNAME"
  name    = each.value.subdomain
  content = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
  ttl     = 1
  proxied = true
}

# ============================================
# DNS records for direct TCP services (RDP, SSH)
# ============================================

resource "cloudflare_dns_record" "direct_service" {
  for_each = local.tunnel_direct_services

  zone_id = local.effective_cloudflare_zone_id
  type    = "CNAME"
  name    = each.value.subdomain
  content = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
  ttl     = 1
  proxied = true
}
