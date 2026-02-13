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
