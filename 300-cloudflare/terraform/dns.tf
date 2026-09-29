# ============================================
# DNS records for homelab services
# ============================================

resource "cloudflare_dns_record" "homelab" {
  for_each = local.homelab_services

  zone_id = local.effective_cloudflare_zone_id
  type    = "CNAME"
  name    = each.value.subdomain
  content = "${module.tunnels["homelab"].tunnel_id}.cfargotunnel.com"
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
  content = "${module.tunnels["homelab"].tunnel_id}.cfargotunnel.com"
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
  content = "${module.tunnels["homelab"].tunnel_id}.cfargotunnel.com"
  ttl     = 1
  proxied = true
}

# ============================================
# Import pre-existing code.jclee.me record
# (created out-of-band via CF API on 2026-07-23; remove this block after first successful CI apply)
# ============================================
import {
  to = cloudflare_dns_record.tcp_services["code"]
  id = "ed060daac18345f6900fc5a661dc94f9/57f10aa256a6aa51f78bb2f1eaf13d9e"
}

# ============================================
# DNS records for direct HTTP services (no reverse proxy)
# ============================================

resource "cloudflare_dns_record" "direct" {
  for_each = local.direct_services

  zone_id = local.effective_cloudflare_zone_id
  type    = "CNAME"
  name    = each.value.subdomain
  content = "${module.tunnels["homelab"].tunnel_id}.cfargotunnel.com"
  ttl     = 1
  proxied = true
}

# ============================================
# Import pre-existing direct-service DNS records
# (created out-of-band via CF API on 2026-07-23; all import blocks in this
# file are removable after the first successful CI apply)
# ============================================

import {
  to = cloudflare_dns_record.direct["grafana"]
  id = "ed060daac18345f6900fc5a661dc94f9/5fede6d31f0300ef99cb5875ed62a2a0"
}

import {
  to = cloudflare_dns_record.direct["idle"]
  id = "ed060daac18345f6900fc5a661dc94f9/2a90418f63b46ba2451f102acbf3d6b3"
}

import {
  to = cloudflare_dns_record.direct["youtube"]
  id = "ed060daac18345f6900fc5a661dc94f9/cba5e9eef3eb06fb3589c6ee022bad55"
}
