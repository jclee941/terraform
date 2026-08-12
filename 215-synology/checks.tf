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

check "proxmox_monitor_secrets" {
  assert {
    condition = !var.enable_proxmox_monitor || alltrue([
      length(local.proxmox_monitor_endpoint) > 0,
      length(local.proxmox_monitor_api_token) > 0,
      length(local.proxmox_monitor_telegram_token) > 0,
      length(local.proxmox_monitor_chat_id) > 0,
    ])
    error_message = "Proxmox monitor requires the Proxmox endpoint/API token and Telegram bot token/chat_id from 1Password."
  }
}
