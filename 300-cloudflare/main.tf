provider "onepassword" {
  service_account_token = trimspace(var.op_service_account_token)
}

module "onepassword_secrets" {
  source = "../modules/shared/onepassword-secrets"
}

locals {
  cloudflare_secret = trimspace(coalesce(module.onepassword_secrets.secrets.cloudflare_api_key, ""))
  cloudflare_email  = trimspace(coalesce(module.onepassword_secrets.metadata.cloudflare_email, ""))
  is_api_token      = startswith(local.cloudflare_secret, "v1.0-")
}

provider "cloudflare" {
  api_token = local.is_api_token ? local.cloudflare_secret : null
  api_key   = local.is_api_token ? null : local.cloudflare_secret
  email     = local.is_api_token ? null : local.cloudflare_email
}

provider "github" {
  owner = var.github_owner
  token = var.github_token
}
