provider "onepassword" {
  service_account_token = trimspace(var.op_service_account_token)
}

module "onepassword_secrets" {
  source = "../modules/shared/onepassword-secrets"
}

provider "cloudflare" {
  api_token = trimspace(module.onepassword_secrets.secrets.cloudflare_api_key)
}

provider "github" {
  owner = var.github_owner
  token = var.github_token
}
