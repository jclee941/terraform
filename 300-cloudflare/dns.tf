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
# DNS records for TCP services (SSH/RDP)
# ============================================

resource "cloudflare_dns_record" "tcp_services" {
  for_each = local.tcp_services

  zone_id = local.effective_cloudflare_zone_id
  type    = "CNAME"
  name    = each.value.subdomain
  content = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
  ttl     = 1
  proxied = true
}

# ============================================
# DNS record for Logstash Ingest (Logpush)
# ============================================

resource "cloudflare_dns_record" "logstash_ingest" {
  zone_id = local.effective_cloudflare_zone_id
  type    = "CNAME"
  name    = "logstash-ingest"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
  ttl     = 1
  proxied = true
}
