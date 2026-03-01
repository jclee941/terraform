# =============================================================================
# 1PASSWORD INTEGRATION
# =============================================================================

module "onepassword_secrets" {
  source     = "../modules/shared/onepassword-secrets"
  vault_name = var.onepassword_vault_name
}

locals {
  # 1Password lookup: prefer xoxb bot token, fall back to xoxp user token
  _slack_xoxb                 = trimspace(try(module.onepassword_secrets.secrets["slack_bot_token"], ""))
  _slack_xoxp                 = trimspace(try(module.onepassword_secrets.secrets["slack_mcp_xoxp_token"], ""))
  _slack_token_from_1password = local._slack_xoxb != "" ? local._slack_xoxb : local._slack_xoxp

  # Effective value: 1Password takes priority, variable fallback
  effective_slack_token = local._slack_token_from_1password != "" ? local._slack_token_from_1password : trimspace(var.slack_bot_token)

  # Guard: channel management requires a bot token (xoxb) — user tokens lack channels:manage scope
  _slack_enabled = nonsensitive(local._slack_xoxb != "")
}
