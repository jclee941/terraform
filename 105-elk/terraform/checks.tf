# =============================================
# Check Blocks — 105-elk
# =============================================

check "required_secrets" {
  assert {
    condition = alltrue([
      for k in [
        "elk_elastic_password",
      ] : length(trimspace(lookup(module.onepassword_secrets.secrets, k, ""))) > 0
    ])
    error_message = "Required 1Password secrets are missing or empty. Required keys: elk_elastic_password"
  }
}
