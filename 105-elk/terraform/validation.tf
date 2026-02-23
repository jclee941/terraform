# =============================================================================
# INPUT VALIDATION (effective values from 1Password or variables)
# =============================================================================

resource "terraform_data" "validate_credentials" {
  lifecycle {
    precondition {
      condition     = var.elasticsearch_username == "" || local.effective_elasticsearch_password != ""
      error_message = "Elasticsearch password must be provided via 1Password or var.elasticsearch_password when username is set."
    }
  }
}
