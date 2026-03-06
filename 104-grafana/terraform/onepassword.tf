# =============================================================================
# 1PASSWORD INTEGRATION
# =============================================================================

module "onepassword_secrets" {
  source     = "../../modules/shared/onepassword-secrets"
  vault_name = var.onepassword_vault_name
}

locals {
  # 1Password lookups (fallback to empty string if not available)
  _grafana_auth_from_1password       = trimspace(try(nonsensitive(module.onepassword_secrets.secrets["grafana_service_account_token"]), ""))
  _grafana_admin_password_from_1pass = trimspace(try(nonsensitive(module.onepassword_secrets.secrets["grafana_admin_password"]), ""))
  _slack_webhook_url_from_1password  = trimspace(try(nonsensitive(module.onepassword_secrets.secrets["slack_webhook_url"]), ""))

  _grafana_admin_password = trimspace(var.grafana_admin_password) != "" ? trimspace(var.grafana_admin_password) : local._grafana_admin_password_from_1pass
  _grafana_basic_auth     = local._grafana_admin_password != "" ? "${trimspace(var.grafana_admin_username)}:${local._grafana_admin_password}" : ""

  # Prefer admin basic auth (allows recovery if service account token is revoked), fall back to service account token
  _grafana_service_account_token = trimspace(var.grafana_auth) != "" ? trimspace(var.grafana_auth) : local._grafana_auth_from_1password
  effective_grafana_auth         = local._grafana_basic_auth != "" ? local._grafana_basic_auth : local._grafana_service_account_token
  effective_slack_webhook_url    = local._slack_webhook_url_from_1password != "" ? local._slack_webhook_url_from_1password : var.slack_webhook_url
  _slack_enabled                 = local.effective_slack_webhook_url != ""
}
