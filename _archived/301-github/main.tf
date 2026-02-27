provider "github" {
  owner = var.github_owner
  token = local.effective_github_token
}

provider "onepassword" {}
