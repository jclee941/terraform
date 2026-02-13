# Access Applications
resource "cloudflare_zero_trust_access_application" "apps" {
  for_each = var.access_applications

  account_id                = var.cloudflare_account_id
  name                      = each.value.name
  domain                    = each.value.domain
  type                      = each.value.type
  session_duration          = each.value.session_duration
  auto_redirect_to_identity = each.value.auto_redirect_to_identity
  allowed_idps              = each.value.allowed_idps
}

# Access Policies
resource "cloudflare_zero_trust_access_policy" "policies" {
  for_each = var.access_policies

  account_id     = var.cloudflare_account_id
  application_id = each.value.application_id
  name           = each.value.name
  decision       = each.value.decision
  precedence     = each.value.precedence

  dynamic "include" {
    for_each = each.value.include
    content {
      dynamic "email" {
        for_each = include.value.email != null ? include.value.email : []
        content {
          email = email.value
        }
      }

      dynamic "email_domain" {
        for_each = include.value.email_domain != null ? include.value.email_domain : []
        content {
          domain = email_domain.value
        }
      }

      dynamic "group" {
        for_each = include.value.group != null ? include.value.group : []
        content {
          id = group.value
        }
      }

      dynamic "ip" {
        for_each = include.value.ip != null ? include.value.ip : []
        content {
          ip = ip.value
        }
      }
    }
  }

  dynamic "exclude" {
    for_each = each.value.exclude != null ? each.value.exclude : []
    content {
      dynamic "email" {
        for_each = exclude.value.email != null ? exclude.value.email : []
        content {
          email = email.value
        }
      }

      dynamic "email_domain" {
        for_each = exclude.value.email_domain != null ? exclude.value.email_domain : []
        content {
          domain = email_domain.value
        }
      }

      dynamic "group" {
        for_each = exclude.value.group != null ? exclude.value.group : []
        content {
          id = group.value
        }
      }

      dynamic "ip" {
        for_each = exclude.value.ip != null ? exclude.value.ip : []
        content {
          ip = ip.value
        }
      }
    }
  }
}
