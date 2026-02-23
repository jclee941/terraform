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

data "terraform_remote_state" "infra" {
  backend = "local"

  config = {
    path = "${path.module}/../../100-pve/terraform.tfstate"
  }

  # Defaults allow CI to plan without the 100-pve state file present.
  defaults = {
    host_inventory = {}
  }
}
