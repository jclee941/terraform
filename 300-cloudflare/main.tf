# Auth via CLOUDFLARE_API_TOKEN env var (scoped API token, not deprecated Global API Key)
provider "cloudflare" {}

provider "github" {
  owner = var.github_owner
  token = var.github_token
}
