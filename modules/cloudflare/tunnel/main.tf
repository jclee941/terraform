terraform {
  required_version = ">= 1.7, < 2.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

resource "random_password" "this" {
  length = 64
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "this" {
  account_id    = var.account_id
  name          = var.name
  tunnel_secret = base64encode(random_password.this.result)

  lifecycle {
    ignore_changes = [tunnel_secret, config_src]
  }
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "this" {
  count = var.ingress == null ? 0 : 1

  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this.id

  config = {
    ingress = var.ingress
  }
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "this" {
  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this.id
}
