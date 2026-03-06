provider "cloudflare" {
  api_token = local.effective_cloudflare_api_token != "" ? local.effective_cloudflare_api_token : null
  api_key   = local.effective_cloudflare_api_token == "" && local.effective_cloudflare_api_key != "" ? local.effective_cloudflare_api_key : null
  email     = local.effective_cloudflare_api_token == "" && local.effective_cloudflare_email != "" ? local.effective_cloudflare_email : null
}

provider "cloudflare" {
  alias     = "apikey"
  api_token = local.effective_cloudflare_api_key == "" ? local.effective_cloudflare_api_token : null
  api_key   = local.effective_cloudflare_api_key != "" ? local.effective_cloudflare_api_key : null
  email     = local.effective_cloudflare_email != "" ? local.effective_cloudflare_email : null
}

provider "github" {
  owner = var.github_owner
  token = local.effective_github_token
}

provider "onepassword" {}
