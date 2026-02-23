provider "onepassword" {
  service_account_token = trimspace(var.op_service_account_token)
}

module "onepassword_secrets" {
  count  = trimspace(var.op_service_account_token) != "" ? 1 : 0
  source = "../modules/shared/onepassword-secrets"
}

locals {
  cloudflare_secret = length(module.onepassword_secrets) > 0 ? trimspace(try(coalesce(module.onepassword_secrets[0].secrets.cloudflare_api_key), "")) : ""
  cloudflare_email  = length(module.onepassword_secrets) > 0 ? trimspace(try(coalesce(module.onepassword_secrets[0].metadata.cloudflare_email), "")) : ""
  is_global_api_key = local.cloudflare_secret != "" && can(regex("^[0-9a-f]{37}$", local.cloudflare_secret))
}

provider "cloudflare" {
  api_token = local.is_global_api_key ? null : (local.cloudflare_secret != "" ? local.cloudflare_secret : null)
  api_key   = local.is_global_api_key ? local.cloudflare_secret : null
  email     = local.is_global_api_key ? local.cloudflare_email : null
}

provider "github" {
  owner = var.github_owner
  token = var.github_token
}
