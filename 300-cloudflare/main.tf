provider "cloudflare" {}

provider "github" {
  owner = var.github_owner
  token = local.effective_github_token
}

provider "onepassword" {
  service_account_token = trimspace(var.op_service_account_token)
}
