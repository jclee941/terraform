# =============================================================================
# 1PASSWORD INTEGRATION
# =============================================================================

module "onepassword_secrets" {
  source     = "../modules/shared/onepassword-secrets"
  vault_name = var.onepassword_vault_name
  enable_gcp = true
}

locals {
  # 1Password lookup: SA credentials JSON
  _gcp_credentials_from_1password = trimspace(try(module.onepassword_secrets.secrets["gcp_credentials"], ""))
  _gcp_project_from_1password     = trimspace(try(module.onepassword_secrets.metadata["gcp_project_id"], ""))
  _gcp_region_from_1password      = trimspace(try(module.onepassword_secrets.metadata["gcp_region"], ""))

  # Effective values: 1Password takes priority, variable fallback
  effective_gcp_credentials = local._gcp_credentials_from_1password != "" ? local._gcp_credentials_from_1password : var.gcp_credentials
  effective_gcp_project     = local._gcp_project_from_1password != "" ? local._gcp_project_from_1password : var.gcp_project
  effective_gcp_region      = local._gcp_region_from_1password != "" ? local._gcp_region_from_1password : var.gcp_region

  # Guard: GCP operations require credentials (uncomment when adding resources)
  # _gcp_enabled = nonsensitive(local._gcp_credentials_from_1password != "")
}
