# =============================================================================
# 1PASSWORD INTEGRATION
# =============================================================================

module "onepassword_secrets" {
  source     = "../modules/shared/onepassword-secrets"
  vault_name = var.onepassword_vault_name
}

locals {
  # 1Password lookup (fallback to empty string if not available)
  _slack_token_from_1password = trimspace(try(module.onepassword_secrets.secrets["slack_bot_token"], ""))

  # Effective value: 1Password takes priority, variable fallback
  effective_slack_token = local._slack_token_from_1password != "" ? local._slack_token_from_1password : trimspace(var.slack_bot_token)
}
