# Zero Trust Tunnels
resource "cloudflare_zero_trust_tunnel_cloudflared" "tunnels" {
  for_each = var.tunnels

  account_id    = var.cloudflare_account_id
  name          = each.value.name
  tunnel_secret = each.value.tunnel_secret != null ? each.value.tunnel_secret : base64encode(random_bytes.tunnel_secret[each.key].result)
  config_src    = each.value.config_src
}

# Generate random tunnel secrets for tunnels that don't provide one
resource "random_bytes" "tunnel_secret" {
  for_each = {
    for k, v in var.tunnels : k => v
    if v.tunnel_secret == null
  }

  length = 32
}

# Tunnel Configuration (for cloudflare-managed config)
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "config" {
  for_each = {
    for k, v in var.tunnels : k => v
    if v.config != null && v.config_src == "cloudflare"
  }

  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.tunnels[each.key].id

  config {
    dynamic "ingress_rule" {
      for_each = each.value.config.ingress
      content {
        hostname = ingress_rule.value.hostname
        service  = ingress_rule.value.service
        path     = ingress_rule.value.path
      }
    }
  }
}
