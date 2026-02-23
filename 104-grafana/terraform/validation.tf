# =============================================================================
# INPUT VALIDATION (effective values from 1Password or variables)
# =============================================================================

resource "terraform_data" "validate_credentials" {
  lifecycle {
    precondition {
      condition     = local.effective_grafana_auth != ""
      error_message = "Grafana auth token must be provided via 1Password or var.grafana_auth."
    }
  }
}
