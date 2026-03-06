# =============================================================================
# INPUT VALIDATION (effective values from 1Password or variables)
# =============================================================================

resource "terraform_data" "validate_credentials" {
  lifecycle {
    precondition {
      condition     = local.effective_grafana_auth != ""
      error_message = "Provide Grafana admin credentials (username/password) or a service account token via 1Password or variables."
    }
  }
}
