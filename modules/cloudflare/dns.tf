# DNS Records
resource "cloudflare_dns_record" "records" {
  for_each = var.dns_records

  zone_id = var.cloudflare_zone_id
  name    = each.value.name
  type    = each.value.type
  content = each.value.content
  proxied = each.value.proxied
  ttl     = each.value.ttl
}

# Tunnel DNS Records (auto-generated for tunnels)
resource "cloudflare_dns_record" "tunnel_cnames" {
  for_each = var.tunnels

  zone_id = var.cloudflare_zone_id
  name    = each.value.name
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.tunnels[each.key].id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}
