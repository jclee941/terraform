module "onepassword_secrets" {
  source = "../modules/shared/onepassword-secrets"
}

provider "cloudflare" {
  api_key = module.onepassword_secrets.secrets.cloudflare_api_key
  email   = module.onepassword_secrets.secrets.cloudflare_email
}

provider "github" {
  owner = var.github_owner
  token = var.github_token
}

provider "onepassword" {}
