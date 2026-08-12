# -----------------------------------------------------------------------------
# 1Password Secrets — Synology DSM credentials
# Priority: 1Password > variable fallback
# -----------------------------------------------------------------------------

module "onepassword_secrets" {
  source          = "../modules/shared/onepassword-secrets"
  vault_name      = var.onepassword_vault_name
  enable_synology = true
}

locals {
  _synology_user_from_1password     = trimspace(try(module.onepassword_secrets.secrets["synology_user"], ""))
  _synology_password_from_1password = trimspace(try(module.onepassword_secrets.secrets["synology_password"], ""))

  proxmox_monitor_endpoint       = trimspace(try(module.onepassword_secrets.connection_info["proxmox_endpoint"], ""))
  proxmox_monitor_api_token      = trimspace(try(module.onepassword_secrets.secrets["proxmox_api_token_value"], ""))
  proxmox_monitor_telegram_token = trimspace(try(module.onepassword_secrets.secrets["telegram_bot_token"], ""))
  proxmox_monitor_chat_id        = trimspace(try(module.onepassword_secrets.secrets["telegram_chat_id"], ""))

  effective_synology_user     = local._synology_user_from_1password != "" ? local._synology_user_from_1password : trimspace(var.synology_user)
  effective_synology_password = local._synology_password_from_1password != "" ? local._synology_password_from_1password : trimspace(var.synology_password)
}
