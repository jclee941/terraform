# ──────────────────────────────────────────────────────────────────────────────
# Service Accounts — programmatic API access for monitoring consumers
# ──────────────────────────────────────────────────────────────────────────────

resource "grafana_service_account" "terraform" {
  name = "terraform"
  role = "Admin"
}

resource "grafana_service_account_token" "terraform" {
  name               = "terraform-token"
  service_account_id = grafana_service_account.terraform.id
}

resource "grafana_service_account" "monitoring" {
  name = "monitoring-readonly"
  role = "Viewer"
}

resource "grafana_service_account_token" "monitoring" {
  name               = "monitoring-token"
  service_account_id = grafana_service_account.monitoring.id
}

output "grafana_sa_token_terraform" {
  description = "Grafana service account token for Terraform operations"
  value       = grafana_service_account_token.terraform.key
  sensitive   = true
}

output "grafana_sa_token_monitoring" {
  description = "Grafana read-only service account token for monitoring consumers"
  value       = grafana_service_account_token.monitoring.key
  sensitive   = true
}
