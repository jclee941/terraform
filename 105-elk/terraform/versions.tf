terraform {
  required_version = ">= 1.7, < 2.0"

  backend "local" {}

  required_providers {
    elasticstack = {
      source  = "elastic/elasticstack"
      version = "~> 0.13"
    }
    onepassword = {
      source  = "1Password/onepassword"
      version = "~> 3.2"
    }
  }
}
