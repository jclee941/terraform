# -----------------------------------------------------------------------------
# 1Password Secrets — Synology DSM + Docker Registry (MinIO) credentials
# Priority: 1Password > variable fallback
# -----------------------------------------------------------------------------

module "onepassword_secrets" {
  source          = "../modules/shared/onepassword-secrets"
  vault_name      = var.onepassword_vault_name
  enable_synology = true
  enable_registry = true
}

locals {
  _synology_user_from_1password     = trimspace(try(module.onepassword_secrets.secrets["synology_user"], ""))
  _synology_password_from_1password = trimspace(try(module.onepassword_secrets.secrets["synology_password"], ""))

  effective_synology_user     = local._synology_user_from_1password != "" ? local._synology_user_from_1password : trimspace(var.synology_user)
  effective_synology_password = local._synology_password_from_1password != "" ? local._synology_password_from_1password : trimspace(var.synology_password)

  # Docker Registry / MinIO credentials (1Password priority, variable fallback)
  _minio_user_from_1password     = trimspace(try(module.onepassword_secrets.secrets["registry_minio_user"], ""))
  _minio_password_from_1password = trimspace(try(module.onepassword_secrets.secrets["registry_minio_password"], ""))

  effective_minio_user     = local._minio_user_from_1password != "" ? local._minio_user_from_1password : trimspace(var.minio_root_user)
  effective_minio_password = local._minio_password_from_1password != "" ? local._minio_password_from_1password : trimspace(var.minio_root_password)
}
