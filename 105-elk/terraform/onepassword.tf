# =============================================================================
# 1PASSWORD INTEGRATION
# =============================================================================

module "onepassword_secrets" {
  source     = "../../modules/shared/onepassword-secrets"
  vault_name = var.onepassword_vault_name
}

locals {
  # 1Password lookups (fallback to empty string if not available)
  _elasticsearch_password_from_1password = trimspace(try(module.onepassword_secrets.secrets["elk_elastic_password"], ""))

  # Effective values: 1Password takes priority, variable fallback
  effective_elasticsearch_password = local._elasticsearch_password_from_1password != "" ? local._elasticsearch_password_from_1password : trimspace(var.elasticsearch_password)
}
