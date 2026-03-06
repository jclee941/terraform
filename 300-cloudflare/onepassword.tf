# =============================================================================
# 1PASSWORD INTEGRATION
# =============================================================================

module "onepassword_secrets" {
  source     = "../modules/shared/onepassword-secrets"
  vault_name = var.onepassword_vault_name
}

locals {
  # 1Password lookups (fallback to empty string if not available)
  _cloudflare_account_id_from_1password      = trimspace(try(module.onepassword_secrets.metadata["cloudflare_account_id"], ""))
  _cloudflare_zone_id_from_1password         = trimspace(try(module.onepassword_secrets.metadata["cloudflare_zone_id"], ""))
  _cloudflare_api_key_from_1password         = trimspace(try(module.onepassword_secrets.secrets["cloudflare_api_key"], ""))
  _cloudflare_api_token_from_1password       = trimspace(try(module.onepassword_secrets.secrets["cloudflare_api_token"], ""))
  _cloudflare_email_from_1password           = trimspace(try(module.onepassword_secrets.metadata["cloudflare_email"], ""))
  _github_token_from_1password               = trimspace(try(module.onepassword_secrets.secrets["github_personal_access_token"], ""))
  _google_oauth_client_id_from_1password     = trimspace(try(module.onepassword_secrets.secrets["google_oauth_client_id"], ""))
  _google_oauth_client_secret_from_1password = trimspace(try(module.onepassword_secrets.secrets["google_oauth_client_secret"], ""))
  _cloudflare_api_key_from_var               = trimspace(var.cloudflare_api_key)

  cloudflare_api_key_pattern = "^[0-9a-f]{37}$"

  cloudflare_api_key_from_1password = can(regex(local.cloudflare_api_key_pattern, local._cloudflare_api_key_from_1password)) ? local._cloudflare_api_key_from_1password : ""
  cloudflare_api_key_from_var       = can(regex(local.cloudflare_api_key_pattern, local._cloudflare_api_key_from_var)) ? local._cloudflare_api_key_from_var : ""

  # Effective values: 1Password takes priority, variable fallback
  effective_cloudflare_account_id      = local._cloudflare_account_id_from_1password != "" ? local._cloudflare_account_id_from_1password : trimspace(var.cloudflare_account_id)
  effective_cloudflare_zone_id         = local._cloudflare_zone_id_from_1password != "" ? local._cloudflare_zone_id_from_1password : trimspace(var.cloudflare_zone_id)
  effective_cloudflare_api_token       = local._cloudflare_api_token_from_1password != "" ? local._cloudflare_api_token_from_1password : trimspace(var.cloudflare_api_token)
  effective_cloudflare_api_key         = local.cloudflare_api_key_from_1password != "" ? local.cloudflare_api_key_from_1password : local.cloudflare_api_key_from_var
  effective_cloudflare_email           = local._cloudflare_email_from_1password != "" ? local._cloudflare_email_from_1password : trimspace(var.cloudflare_email)
  effective_github_token               = local._github_token_from_1password != "" ? local._github_token_from_1password : trimspace(var.github_token)
  effective_google_oauth_client_id     = local._google_oauth_client_id_from_1password != "" ? local._google_oauth_client_id_from_1password : trimspace(var.google_oauth_client_id)
  effective_google_oauth_client_secret = local._google_oauth_client_secret_from_1password != "" ? local._google_oauth_client_secret_from_1password : trimspace(var.google_oauth_client_secret)
  google_idp_configured                = local.effective_google_oauth_client_id != "" && local.effective_google_oauth_client_secret != ""
}
