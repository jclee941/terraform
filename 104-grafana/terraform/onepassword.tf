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

  _grafana_admin_password_var    = trimspace(var.grafana_admin_password)
  _grafana_basic_auth_from_var   = local._grafana_admin_password_var != "" ? "${trimspace(var.grafana_admin_username)}:${local._grafana_admin_password_var}" : ""
  _grafana_basic_auth_from_1pass = local._grafana_admin_password_from_1pass != "" ? "${trimspace(var.grafana_admin_username)}:${local._grafana_admin_password_from_1pass}" : ""

  # Prefer service account token (1Password → var), allow explicit admin override via variable, and only fall back to 1Password admin if no token is available.
  _grafana_service_account_token = local._grafana_auth_from_1password != "" ? local._grafana_auth_from_1password : trimspace(var.grafana_auth)
  effective_grafana_auth         = local._grafana_basic_auth_from_var != "" ? local._grafana_basic_auth_from_var : (local._grafana_service_account_token != "" ? local._grafana_service_account_token : local._grafana_basic_auth_from_1pass)
  effective_slack_webhook_url    = local._slack_webhook_url_from_1password != "" ? local._slack_webhook_url_from_1password : var.slack_webhook_url
  _slack_enabled                 = local.effective_slack_webhook_url != ""
}
