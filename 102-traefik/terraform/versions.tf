terraform {
  required_version = ">= 1.7, < 2.0"

  backend "local" {}

  # NOTE: LXC lifecycle is owned by 100-pve/main.tf (module "lxc" for_each).
  # Config deployment is also owned by 100-pve via config-renderer templates.
  # This workspace is reserved for future Traefik provider resources
  # (e.g., direct API management), similar to 104-grafana/terraform/.
  required_providers {}
}

data "terraform_remote_state" "infra" {
  backend = "local"

  config = {
    path = "${path.module}/../../100-pve/terraform.tfstate"
  }
}
