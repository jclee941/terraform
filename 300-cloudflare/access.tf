# ============================================
# Cloudflare Access for Synology NAS
# ============================================

resource "cloudflare_zero_trust_access_application" "synology" {
  zone_id          = local.effective_cloudflare_zone_id
  name             = "Synology NAS"
  domain           = var.synology_domain
  type             = "self_hosted"
  session_duration = "24h"
}

resource "cloudflare_zero_trust_access_policy" "synology_email" {
  account_id = local.effective_cloudflare_account_id
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

  zone_id          = local.effective_cloudflare_zone_id
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

# ============================================
# Cloudflare Access for direct TCP services (RDP, SSH)
# ============================================

resource "cloudflare_zero_trust_access_application" "direct_service" {
  for_each = local.tunnel_direct_services

  zone_id          = local.effective_cloudflare_zone_id
  name             = "${each.value.subdomain} (${upper(split("://", each.value.service)[0])})"
  domain           = "${each.value.subdomain}.${var.homelab_domain}"
  type             = "self_hosted"
  session_duration = "24h"

  policies = [{
    decision = "allow"
    name     = "${each.value.subdomain} Email Access"
    include = [for email in var.access_allowed_emails : {
      email = {
        email = email
      }
    }]
  }]
}
