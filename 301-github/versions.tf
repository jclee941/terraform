terraform {
  required_version = ">= 1.7, < 2.0"

  backend "s3" {
    key = "301-github/terraform.tfstate"
  }

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.6"
    }
  }
}
