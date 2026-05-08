# =============================================
# Check Blocks — 215-synology
# =============================================

check "required_secrets" {
  assert {
    condition = (
      length(trimspace(lookup(module.onepassword_secrets.secrets, "synology_user", ""))) > 0 &&
      length(trimspace(lookup(module.onepassword_secrets.secrets, "synology_password", ""))) > 0
      ) || (
      length(trimspace(var.synology_user)) > 0 &&
      length(trimspace(var.synology_password)) > 0
    )
    error_message = "Synology credentials are required. Set 1Password keys (synology_user, synology_password) or TF_VAR_synology_user/TF_VAR_synology_password."
  }
}


check "registry_credentials" {
  assert {
    condition = (
      !var.enable_registry ||
      (length(trimspace(local.effective_minio_user)) > 0 &&
      length(trimspace(local.effective_minio_password)) > 0)
    )
    error_message = "Registry is enabled but MinIO credentials are empty. Set 1Password item 'registry' (username/password) or TF_VAR_minio_root_user/TF_VAR_minio_root_password."
  }
}
