provider "cloudflare" {
  api_key = var.cloudflare_api_key
  email   = var.cloudflare_email
}

provider "github" {
  owner = var.github_owner
  token = var.github_token
}

provider "vault" {
  address          = var.vault_address
  token            = var.vault_token
  skip_child_token = true
}
