terraform {
  required_version = ">= 1.7, < 2.0"

  backend "s3" {
    key = "102-traefik/terraform.tfstate"
  }

  # NOTE: LXC lifecycle is owned by 100-pve/main.tf (module "lxc" for_each).
  # This workspace only manages app-level config deployment via lxc-config.
  required_providers {}
}

# ---------------------------------------------------------------------------
# Remote State: consume 100-pve infrastructure outputs
# Provides host_inventory (IPs, ports, VMIDs) — replaces deprecated module.inventory
# ---------------------------------------------------------------------------
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

locals {
  hosts = data.terraform_remote_state.infra.outputs.host_inventory
}

module "lxc_config" {
  source = "../../modules/proxmox/lxc-config"

  deploy_lxc_configs = var.deploy_lxc_configs
  mcp_host           = local.hosts.mcphub.ip

  lxc_containers = {
    traefik = {
      vmid       = local.hosts.traefik.vmid
      hostname   = "traefik"
      ip_address = local.hosts.traefik.ip
      deploy     = var.deploy_lxc_configs

      config_files = {
        "elk.yml" = {
          path    = "/etc/traefik/dynamic/elk.yml"
          content = file("${path.root}/../config/elk.yml")
        }
        "glitchtip.yml" = {
          path    = "/etc/traefik/dynamic/glitchtip.yml"
          content = file("${path.root}/../config/glitchtip.yml")
        }
      }
    }
  }
}
