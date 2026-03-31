terraform {
  required_version = ">= 1.7, < 2.0"

  backend "local" {}

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.94"
    }
    onepassword = {
      source  = "1Password/onepassword"
      version = "~> 3.2"
    }
  }
}
