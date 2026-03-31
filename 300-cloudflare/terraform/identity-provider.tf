# =============================================================================
# IDENTITY PROVIDERS
# =============================================================================
# Prerequisites for Google IdP:
# 1. Create OAuth 2.0 Client ID at https://console.cloud.google.com/apis/credentials
# 2. Application type: Web application
# 3. Authorized redirect URI: https://<team>.cloudflareaccess.com/cdn-cgi/access/callback
# 4. Store credentials in 1Password vault "homelab",
#    item "cloudflare", section "secrets":
#    - Field: "google_oauth_client_id"
#    - Field: "google_oauth_client_secret"
# =============================================================================

# Google OAuth Identity Provider (conditional — created only when credentials are configured)
resource "cloudflare_zero_trust_access_identity_provider" "google" {
  count = local.google_idp_configured ? 1 : 0

  account_id = local.effective_cloudflare_account_id
  name       = "Google"
  type       = "google"
  config = {
    client_id     = local.effective_google_oauth_client_id
    client_secret = local.effective_google_oauth_client_secret
  }
}

# Email OTP fallback — recovery path when Google auth is unavailable
resource "cloudflare_zero_trust_access_identity_provider" "otp" {
  account_id = local.effective_cloudflare_account_id
  name       = "Email OTP"
  type       = "onetimepin"
  config     = {}
}

# Ordered IdP list for Access applications:
# - Google first (primary SSO) when configured
# - OTP always present (fallback)
locals {
  allowed_identity_providers = concat(
    local.google_idp_configured ? [cloudflare_zero_trust_access_identity_provider.google[0].id] : [],
    [cloudflare_zero_trust_access_identity_provider.otp.id]
  )
}
