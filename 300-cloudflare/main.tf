data "vault_kv_secret_v2" "cloudflare" {
  mount = var.vault_mount_path
  name  = "homelab/cloudflare"
}

provider "cloudflare" {
  api_key = data.vault_kv_secret_v2.cloudflare.data["api_key"]
  email   = data.vault_kv_secret_v2.cloudflare.data["email"]
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
