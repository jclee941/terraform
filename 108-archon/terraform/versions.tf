terraform {
  required_version = ">= 1.7, < 2.0"

  backend "local" {}

  # LXC lifecycle and config deployment owned by 100-pve/main.tf.
  # This workspace is reserved for future Archon-specific provider resources.
  required_providers {}
}

data "terraform_remote_state" "infra" {
  backend = "local"

  config = {
    path = "${path.module}/../../100-pve/terraform.tfstate"
  }
}
