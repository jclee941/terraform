# =============================================
# Check Blocks — 301-github
# =============================================

check "required_secrets" {
  assert {
    condition = alltrue([
      for k in [
        "github_personal_access_token",
      ] : length(trimspace(lookup(module.onepassword_secrets.secrets, k, ""))) > 0
    ])
    error_message = "Required 1Password secrets are missing or empty. Required keys: github_personal_access_token"
  }
}
