# =============================================================================
# 1PASSWORD INTEGRATION
# =============================================================================

module "onepassword_secrets" {
  source     = "../../modules/shared/onepassword-secrets"
  vault_name = var.onepassword_vault_name
}

locals {
  # 1Password lookups (fallback to empty string if not available)
  _grafana_auth_from_1password      = trimspace(try(module.onepassword_secrets.secrets["grafana_service_account_token"], ""))
  _slack_webhook_url_from_1password = trimspace(try(module.onepassword_secrets.secrets["slack_webhook_url"], ""))

  # Effective values: variable takes priority (1P token may be stale/rotated)
  effective_grafana_auth      = trimspace(var.grafana_auth) != "" ? trimspace(var.grafana_auth) : local._grafana_auth_from_1password
  effective_slack_webhook_url = local._slack_webhook_url_from_1password != "" ? local._slack_webhook_url_from_1password : var.slack_webhook_url
  _slack_enabled              = local.effective_slack_webhook_url != ""
}
