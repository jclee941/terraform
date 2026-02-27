terraform {
  required_version = ">= 1.7, < 2.0"

  backend "local" {}

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.6"
    }
    onepassword = {
      source  = "1Password/onepassword"
      version = "~> 3.2"
    }
  }
}

# ---------------------------------------------------------------------------
# Remote State: consume 100-pve infrastructure outputs
# Provides host_inventory (IPs, ports, VMIDs) and service_urls (derived URLs).
# ---------------------------------------------------------------------------
data "terraform_remote_state" "infra" {
  backend = "local"

  config = {
    path = "${path.module}/../100-pve/terraform.tfstate"
  }

  # Defaults allow CI to plan without the 100-pve state file present.
  # locals.tf already wraps access in try() for double safety.
  defaults = {
    host_inventory = {}
    service_urls   = {}
  }
}
