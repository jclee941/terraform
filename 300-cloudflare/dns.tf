# ============================================
# DNS records for homelab services
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
