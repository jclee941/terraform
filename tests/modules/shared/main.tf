terraform {
  required_version = ">= 1.7, < 2.0"

  required_providers {
    onepassword = {
      source  = "1Password/onepassword"
      version = "~> 3.2"
    }
  }
}
