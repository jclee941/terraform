# =============================================================================
# INPUT VALIDATION (effective values from 1Password or variables)
# =============================================================================

resource "terraform_data" "validate_credentials" {
  lifecycle {
    precondition {
      condition     = can(regex("^[0-9a-f]{32}$", local.effective_cloudflare_account_id))
      error_message = "Cloudflare account ID must be a 32-character lowercase hex string (from 1Password or var.cloudflare_account_id)."
    }

    precondition {
      condition     = can(regex("^[0-9a-f]{32}$", local.effective_cloudflare_zone_id))
      error_message = "Cloudflare zone ID must be a 32-character lowercase hex string (from 1Password or var.cloudflare_zone_id)."
    }
  }
}
