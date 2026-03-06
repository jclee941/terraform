terraform {
  required_version = ">= 1.7, < 2.0"

  backend "local" {}

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.22"
    }
    onepassword = {
      source  = "1Password/onepassword"
      version = "~> 3.2"
    }
  }
}
