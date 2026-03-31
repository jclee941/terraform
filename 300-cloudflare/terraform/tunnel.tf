# ============================================
# Cloudflare Tunnel for Synology NAS
# ============================================

resource "random_password" "tunnel_secret" {
  length = 64
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "synology" {
  account_id    = local.effective_cloudflare_account_id
  name          = "215-synology"
  tunnel_secret = base64encode(random_password.tunnel_secret.result)

  lifecycle {
    ignore_changes = [tunnel_secret, config_src]
  }
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "synology" {
  account_id = local.effective_cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.synology.id

  config = {
    ingress = [
      {
        hostname = var.synology_domain
        service  = "http://${var.synology_nas_ip}:${var.synology_nas_port}"
      },
      {
        service = "http_status:404"
      }
    ]
  }
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "synology" {
  account_id = local.effective_cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.synology.id
}

# ============================================
# Cloudflare tunnel for homelab services
# ============================================

resource "random_password" "homelab_tunnel_secret" {
  length = 64
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "homelab" {
  account_id    = local.effective_cloudflare_account_id
  name          = "traefik"
  tunnel_secret = base64encode(random_password.homelab_tunnel_secret.result)

  lifecycle {
    ignore_changes = [tunnel_secret, config_src]
  }
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "homelab" {
  account_id = local.effective_cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab.id

  config = {
    ingress = concat(
      [for key, svc in local.homelab_services : {
        hostname = "${svc.subdomain}.${var.homelab_domain}"
        service  = "http://localhost:80"
      }],
      [for key, svc in local.tcp_services : {
        hostname = "${svc.subdomain}.${var.homelab_domain}"
        service  = svc.origin
      }],
      [{
        hostname = "logstash-ingest.${var.homelab_domain}"
        service  = "http://${var.elk_ip}:8080"
      }],
      [{ service = "http_status:404" }]
    )
  }
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "homelab" {
  account_id = local.effective_cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab.id
}


# ============================================
# Cloudflare Tunnel for JCLee Workstation (physical PC, host ID 80)
# ============================================

resource "random_password" "jclee_tunnel_secret" {
  length = 64
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "jclee" {
  account_id    = local.effective_cloudflare_account_id
  name          = "80-jclee"
  tunnel_secret = base64encode(random_password.jclee_tunnel_secret.result)

  lifecycle {
    ignore_changes = [tunnel_secret, config_src]
  }
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "jclee" {
  account_id = local.effective_cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.jclee.id
}
