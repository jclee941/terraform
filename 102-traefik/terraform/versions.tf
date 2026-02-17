terraform {
  required_version = ">= 1.7, < 2.0"

  backend "s3" {
    key = "102-traefik/terraform.tfstate"
  }

  # NOTE: LXC lifecycle is owned by 100-pve/main.tf (module "lxc" for_each).
  # Config deployment is also owned by 100-pve via config-renderer templates.
  # This workspace is reserved for future Traefik provider resources
  # (e.g., direct API management), similar to 104-grafana/terraform/.
  required_providers {}
}

data "terraform_remote_state" "infra" {
  backend = "s3"

  config = {
    bucket                      = "jclee-tf-state"
    key                         = "100-pve/terraform.tfstate"
    region                      = "auto"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    use_path_style              = true
    endpoints = {
      s3 = "https://a8d9c67f586acdd15eebcc65ca3aa5bb.r2.cloudflarestorage.com"
    }
  }
}
