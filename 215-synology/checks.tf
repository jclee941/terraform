# =============================================
# Check Blocks — 215-synology
# =============================================

check "required_secrets" {
  assert {
    condition = alltrue([
      for k in [
        "synology_password",
        "synology_user",
      ] : length(trimspace(lookup(module.onepassword_secrets.secrets, k, ""))) > 0
    ])
    error_message = "Required 1Password secrets are missing or empty. Required keys: synology_password, synology_user"
  }
}
