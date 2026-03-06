# =============================================================================
# OUTPUTS
# =============================================================================

output "gcp_project" {
  description = "Active GCP project ID"
  value       = local.effective_gcp_project
}

output "gcp_region" {
  description = "Active GCP region"
  value       = local.effective_gcp_region
}
