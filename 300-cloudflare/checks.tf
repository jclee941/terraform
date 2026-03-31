# =============================================
# Check Blocks — 300-cloudflare
# =============================================

check "required_secrets" {
  assert {
    condition = (
      length(trimspace(local.effective_cloudflare_api_token)) > 0 ||
      length(trimspace(local.effective_cloudflare_api_key)) > 0
    )
    error_message = "Effective credentials are missing. Require at least one Cloudflare credential (API token or API key) from 1Password or variables."
  }
}

check "required_metadata" {
  assert {
    condition = alltrue([
      length(trimspace(local.effective_cloudflare_account_id)) > 0,
      length(trimspace(local.effective_cloudflare_zone_id)) > 0,
      # Email is required only for API key auth; API token auth does not need it
      length(trimspace(local.effective_cloudflare_api_token)) > 0 ? true : length(trimspace(local.effective_cloudflare_email)) > 0
    ])
    error_message = "Effective Cloudflare metadata is missing. Require account_id, zone_id, and email (email only required when using API key instead of API token) from 1Password metadata or variables."
  }
}
