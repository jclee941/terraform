# =============================================================================
# INPUT VALIDATION (effective values from 1Password or variables)
# =============================================================================

resource "terraform_data" "validate_credentials" {
  lifecycle {
    precondition {
      condition     = local.effective_github_token != ""
      error_message = "GitHub token must be provided via 1Password or var.github_token."
    }
  }
}
