terraform {
  required_version = ">= 1.7, < 2.0"

  backend "s3" {
    key = "108-archon/terraform.tfstate"
  }

  # LXC lifecycle owned by 100-pve/main.tf — this workspace manages app config only.
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
  hosts = try(data.terraform_remote_state.infra.outputs.host_inventory, {})
}

module "lxc_config" {
  source = "../../modules/proxmox/lxc-config"

  deploy_lxc_configs = var.deploy_lxc_configs
  mcp_host           = local.hosts.mcphub.ip

  lxc_containers = {
    archon = {
      vmid       = local.hosts.archon.vmid
      hostname   = "archon"
      ip_address = local.hosts.archon.ip
      deploy     = var.deploy_lxc_configs

      config_files = {
        "docker-compose.yml" = {
          path    = "/opt/archon/docker-compose.yml"
          content = file("${path.root}/../docker-compose.yml")
        }
        ".env" = {
          path = "/opt/archon/.env"
          content = templatefile("${path.root}/../templates/.env.tftpl", {
            supabase_url      = var.supabase_url
            supabase_anon_key = var.supabase_anon_key
            openai_api_key    = var.openai_api_key
          })
        }
      }
    }
  }
}
