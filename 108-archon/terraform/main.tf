terraform {
  required_version = ">= 1.7, < 2.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.94.0"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_insecure
}

module "inventory" {
  source = "../../modules/proxmox/inventory"
}

module "lxc" {
  source = "../../modules/proxmox/lxc"

  node_name        = var.node_name
  vmid             = module.inventory.hosts.archon.vmid
  hostname         = "archon"
  ip_address       = module.inventory.hosts.archon.ip
  memory           = 6144
  cores            = 4
  disk_size        = 20
  description      = "Archon AI Knowledge Management + MCP Server"
  network_gateway  = var.network_gateway
  dns_servers      = var.dns_servers
  default_swap     = 2048
  datastore_id     = var.datastore_id
  managed_vmid_min = 101
  managed_vmid_max = 113
  ssh_public_keys  = var.ssh_public_keys
}

module "lxc_config" {
  source = "../../modules/proxmox/lxc-config"

  deploy_lxc_configs = var.deploy_lxc_configs
  mcp_host           = module.inventory.hosts.mcphub.ip

  lxc_containers = {
    archon = {
      vmid       = module.inventory.hosts.archon.vmid
      hostname   = "archon"
      ip_address = module.inventory.hosts.archon.ip
      deploy     = var.deploy_lxc_configs

      config_files = {
        "docker-compose.yml" = {
          path    = "/opt/archon/docker-compose.yml"
          content = file("${path.root}/../docker-compose.yml")
        }
        ".env" = {
          path = "/opt/archon/.env"
          content = templatefile("${path.root}/../templates/.env.tftpl", {
            supabase_url         = var.supabase_url
            supabase_service_key = var.supabase_service_key
          })
        }
      }
    }
  }
}
