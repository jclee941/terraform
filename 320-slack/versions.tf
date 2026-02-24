terraform {
  required_version = ">= 1.7, < 2.0"

  backend "local" {}

  required_providers {
    slack = {
      source  = "pablovarela/slack"
      version = "~> 1.0"
    }
    onepassword = {
      source  = "1Password/onepassword"
      version = "~> 3.2"
    }
  }
}
