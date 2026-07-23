locals {
  cloudflare_tunnels = {
    synology = {
      name = "215-synology"
      ingress = [
        {
          hostname = var.synology_domain
          service  = "http://${var.synology_nas_ip}:${var.synology_nas_port}"
        },
        {
          service = "http_status:404"
        },
      ]
    }
    homelab = {
      name = "traefik"
      ingress = concat(
        [for key, svc in local.homelab_services : {
          hostname = "${svc.subdomain}.${var.homelab_domain}"
          service  = svc.origin
          origin_request = lookup(svc, "no_tls_verify", false) ? {
            no_tls_verify = true
          } : null
        }],
        [for key, svc in local.direct_services : {
          hostname = "${svc.subdomain}.${var.homelab_domain}"
          service  = svc.origin
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
    jclee = {
      name    = "80-jclee"
      ingress = null
    }
  }
}

module "tunnels" {
  source   = "../../modules/cloudflare/tunnel"
  for_each = local.cloudflare_tunnels

  name       = each.value.name
  account_id = local.effective_cloudflare_account_id
  ingress    = each.value.ingress
}

moved {
  from = random_password.tunnel_secret
  to   = module.tunnels["synology"].random_password.this
}

moved {
  from = cloudflare_zero_trust_tunnel_cloudflared.synology
  to   = module.tunnels["synology"].cloudflare_zero_trust_tunnel_cloudflared.this
}

moved {
  from = cloudflare_zero_trust_tunnel_cloudflared_config.synology
  to   = module.tunnels["synology"].cloudflare_zero_trust_tunnel_cloudflared_config.this[0]
}

moved {
  from = random_password.homelab_tunnel_secret
  to   = module.tunnels["homelab"].random_password.this
}

moved {
  from = cloudflare_zero_trust_tunnel_cloudflared.homelab
  to   = module.tunnels["homelab"].cloudflare_zero_trust_tunnel_cloudflared.this
}

moved {
  from = cloudflare_zero_trust_tunnel_cloudflared_config.homelab
  to   = module.tunnels["homelab"].cloudflare_zero_trust_tunnel_cloudflared_config.this[0]
}

moved {
  from = random_password.jclee_tunnel_secret
  to   = module.tunnels["jclee"].random_password.this
}

moved {
  from = cloudflare_zero_trust_tunnel_cloudflared.jclee
  to   = module.tunnels["jclee"].cloudflare_zero_trust_tunnel_cloudflared.this
}
