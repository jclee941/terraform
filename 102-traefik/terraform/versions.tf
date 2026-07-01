terraform {
  required_version = ">= 1.7, < 2.0"

  backend "local" {}

  required_providers {}
}

data "terraform_remote_state" "infra" {
  backend = "local"

  config = {
    path = "${path.module}/../../100-pve/terraform/terraform.tfstate"
  }

  # Defaults allow CI to plan without the 100-pve state file present.
  defaults = {
    host_inventory = {}
  }
}
