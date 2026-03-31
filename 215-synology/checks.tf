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

check "gitlab_runner_token" {
  assert {
    condition = (
      !var.enable_gitlab_runner ||
      length(trimspace(var.gitlab_runner_token)) > 0
    )
    error_message = "GitLab Runner is enabled but runner token is empty. Create a runner in GitLab UI (Settings > CI/CD > Runners) and set TF_VAR_gitlab_runner_token."
  }
}
