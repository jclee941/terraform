# =============================================
# Check Blocks — 300-cloudflare
# =============================================

check "required_secrets" {
  assert {
    condition = length(trimspace(local.effective_github_token)) > 0 && (
      length(trimspace(local.effective_cloudflare_api_token)) > 0 ||
      length(trimspace(local.effective_cloudflare_api_key)) > 0
    )
    error_message = "Effective credentials are missing. Require GitHub token and at least one Cloudflare credential (API token or API key) from 1Password or variables."
  }
}

check "required_metadata" {
  assert {
    condition = alltrue([
      length(trimspace(local.effective_cloudflare_account_id)) > 0,
      length(trimspace(local.effective_cloudflare_zone_id)) > 0,
      length(trimspace(local.effective_cloudflare_email)) > 0
    ])
    error_message = "Effective Cloudflare metadata is missing. Require account_id, zone_id, and email from 1Password metadata or variables."
  }
}
