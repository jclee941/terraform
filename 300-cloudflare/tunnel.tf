# ============================================
# Cloudflare Tunnel for Synology NAS
# ============================================

resource "random_password" "tunnel_secret" {
  length = 64
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "synology" {
  account_id    = var.cloudflare_account_id
  name          = "synology-nas"
  tunnel_secret = base64encode(random_password.tunnel_secret.result)
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "synology" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.synology.id

  config = {
    ingress = [
      {
        hostname = var.synology_domain
        service  = "https://${var.synology_nas_ip}:${var.synology_nas_port}"
        origin_request = {
          no_tls_verify = true
        }
      },
      {
        service = "http_status:404"
      }
    ]
  }
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "synology" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.synology.id
}
