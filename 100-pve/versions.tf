terraform {
  required_version = ">= 1.7, < 2.0"

  backend "s3" {
    key = "100-pve/terraform.tfstate"
  }

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.94"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
  }
}
