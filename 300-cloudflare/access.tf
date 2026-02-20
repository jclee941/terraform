# ============================================
# Cloudflare Access for Synology NAS
# ============================================

resource "cloudflare_zero_trust_access_application" "synology" {
  zone_id          = var.cloudflare_zone_id
  name             = "Synology NAS"
  domain           = var.synology_domain
  type             = "self_hosted"
  session_duration = "24h"
}

resource "cloudflare_zero_trust_access_policy" "synology_email" {
  account_id = var.cloudflare_account_id
  name       = "Email Access"
  decision   = "allow"

  include = [for email in var.access_allowed_emails : {
    email = {
      email = email
    }
  }]
}

# ============================================
# Cloudflare Access for restricted homelab services
# ============================================

resource "cloudflare_zero_trust_access_application" "homelab" {
  for_each = local.restricted_services

  zone_id          = var.cloudflare_zone_id
  name             = each.value.name
  domain           = "${each.value.subdomain}.${var.homelab_domain}"
  type             = "self_hosted"
  session_duration = "24h"

  policies = [{
    decision = "allow"
    name     = "${each.value.name} Email Access"
    include = [for email in var.access_allowed_emails : {
      email = {
        email = email
      }
    }]
  }]
}
