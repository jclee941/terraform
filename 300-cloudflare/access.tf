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
# Cloudflare Access for TCP services (SSH/RDP)
# Extended session (720h) — device trusted after first email auth
# ============================================

resource "cloudflare_zero_trust_access_application" "tcp_services" {
  for_each = local.tcp_services

  zone_id          = local.effective_cloudflare_zone_id
  name             = each.value.name
  domain           = "${each.value.subdomain}.${var.homelab_domain}"
  type             = "self_hosted"
  session_duration = "720h"

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
# Cloudflare Access for Logstash Ingest (M2M)
# ============================================

resource "cloudflare_zero_trust_access_service_token" "logpush" {
  account_id = local.effective_cloudflare_account_id
  name       = "Logpush Worker Traces"
  duration   = "8760h"
}

resource "cloudflare_zero_trust_access_application" "logstash_ingest" {
  zone_id          = local.effective_cloudflare_zone_id
  name             = "Logstash Ingest"
  domain           = "logstash-ingest.${var.homelab_domain}"
  type             = "self_hosted"
  session_duration = "24h"

  policies = [{
    decision = "non_identity"
    name     = "Logpush Service Token"
    include = [{
      any_valid_service_token = {}
    }]
  }]
}
