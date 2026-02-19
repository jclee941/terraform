terraform {
  required_version = ">= 1.7, < 2.0"

  backend "local" {}

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.6"
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
}
