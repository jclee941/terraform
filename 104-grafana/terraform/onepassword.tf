# =============================================================================
# 1PASSWORD INTEGRATION
# =============================================================================

module "onepassword_secrets" {
  source     = "../../modules/shared/onepassword-secrets"
  vault_name = var.onepassword_vault_name
}

locals {
  # 1Password lookups (fallback to empty string if not available)
  _grafana_auth_from_1password = trimspace(try(module.onepassword_secrets.secrets["grafana_service_account_token"], ""))

  # Effective values: 1Password takes priority, variable fallback
  effective_grafana_auth = local._grafana_auth_from_1password != "" ? local._grafana_auth_from_1password : trimspace(var.grafana_auth)
}
