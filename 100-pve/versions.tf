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
    onepassword = {
      source  = "1Password/onepassword"
      version = "~> 3.2"
    }
    # TEMPORARY: Required to process stale vault_agent resources still in state.
    # Remove after apply cleans state (see removed block in main.tf).
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
  }
}
