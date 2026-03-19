# =============================================
# Check Blocks — 104-grafana
# =============================================

check "required_secrets" {
  assert {
    condition = local.effective_grafana_auth != "" && (
      local._grafana_admin_password_from_1pass != "" ||
      local._grafana_admin_password_var != ""
    )
    error_message = "Grafana auth prerequisites are missing. Require effective_grafana_auth and grafana admin password from 1Password or variables."
  }
}
