terraform {
  required_version = ">= 1.7, < 2.0"

  backend "s3" {
    key = "300-cloudflare/terraform.tfstate"
  }

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.6"
    }
    onepassword = {
      source  = "1Password/onepassword"
      version = "~> 3.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
