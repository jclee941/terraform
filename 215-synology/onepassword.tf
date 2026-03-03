# -----------------------------------------------------------------------------
# 1Password Secrets — Synology DSM credentials
# Priority: 1Password > variable fallback
# -----------------------------------------------------------------------------

module "onepassword_secrets" {
  source     = "../modules/shared/onepassword-secrets"
  vault_name = var.onepassword_vault_name
}

locals {
  _synology_user_from_1password     = trimspace(try(module.onepassword_secrets.secrets["synology_user"], ""))
  _synology_password_from_1password = trimspace(try(module.onepassword_secrets.secrets["synology_password"], ""))

  effective_synology_user     = local._synology_user_from_1password != "" ? local._synology_user_from_1password : trimspace(var.synology_user)
  effective_synology_password = local._synology_password_from_1password != "" ? local._synology_password_from_1password : trimspace(var.synology_password)
}
