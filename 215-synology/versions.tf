terraform {
  required_version = ">= 1.7, < 2.0"

  backend "local" {}

  required_providers {
    synology = {
      source  = "synology-community/synology"
      version = "~> 0.6"
    }
    onepassword = {
      source  = "1Password/onepassword"
      version = "~> 3.2"
    }
  }
}
