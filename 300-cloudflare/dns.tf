# ============================================
# DNS Record for Synology Tunnel
# ============================================

resource "cloudflare_dns_record" "synology_tunnel" {
  zone_id = var.cloudflare_zone_id
  type    = "CNAME"
  name    = split(".", var.synology_domain)[0]
  content = "${cloudflare_zero_trust_tunnel_cloudflared.synology.id}.cfargotunnel.com"
  ttl     = 1
  proxied = true
}

# ============================================
# DNS Records for Homelab Services
# ============================================

resource "cloudflare_dns_record" "homelab" {
  for_each = local.homelab_services

  zone_id = var.cloudflare_zone_id
  type    = "CNAME"
  name    = each.value.subdomain
  content = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
  ttl     = 1
  proxied = true
}
