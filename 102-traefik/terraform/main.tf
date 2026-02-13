terraform {
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
  source = "../../modules/inventory"
}

module "lxc" {
  source = "../../modules/lxc"

  node_name        = var.node_name
  vmid             = module.inventory.hosts.traefik.vmid
  hostname         = "traefik"
  ip_address       = module.inventory.hosts.traefik.ip
  memory           = 512
  cores            = 2
  disk_size        = 8
  description      = "Traefik Reverse Proxy + Cloudflare Tunnel"
  network_gateway  = var.network_gateway
  dns_servers      = var.dns_servers
  default_swap     = 512
  datastore_id     = var.datastore_id
  managed_vmid_min = 101
  managed_vmid_max = 113
  ssh_public_keys  = var.ssh_public_keys
}

module "lxc_config" {
  source = "../../modules/lxc-config"

  deploy_lxc_configs = var.deploy_lxc_configs
  mcp_host           = module.inventory.hosts.mcphub.ip

  lxc_containers = {
    traefik = {
      vmid       = module.inventory.hosts.traefik.vmid
      hostname   = "traefik"
      ip_address = module.inventory.hosts.traefik.ip
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
        "mcp.yml" = {
          path    = "/etc/traefik/dynamic/mcp.yml"
          content = file("${path.root}/../config/mcp.yml")
        }
        "vault.yml" = {
          path    = "/etc/traefik/dynamic/vault.yml"
          content = file("${path.root}/../config/vault.yml")
        }
      }
    }
  }
}
