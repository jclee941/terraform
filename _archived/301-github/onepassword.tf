# =============================================================================
# 1PASSWORD INTEGRATION
# =============================================================================

module "onepassword_secrets" {
  source     = "../modules/shared/onepassword-secrets"
  vault_name = var.onepassword_vault_name
}

locals {
  # 1Password lookups (fallback to empty string if not available)
  _github_token_from_1password = trimspace(try(module.onepassword_secrets.secrets["github_personal_access_token"], ""))

  # Effective values: 1Password takes priority, variable fallback
  effective_github_token = local._github_token_from_1password != "" ? local._github_token_from_1password : trimspace(var.github_token)
}
