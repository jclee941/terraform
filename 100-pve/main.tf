terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.94"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_insecure
}

provider "vault" {
  address = var.vault_address
  token   = var.vault_token
}

# =============================================================================
# DATA SOURCES
# =============================================================================

data "proxmox_virtual_environment_nodes" "nodes" {}

# =============================================================================
# HOST INVENTORY (Single Source of Truth)
# =============================================================================

module "hosts" {
  source = "./envs/prod"
}

module "env_config" {
  source = "../modules/proxmox/env-config"

  hosts = module.hosts.hosts
  network = {
    subnet  = var.network_cidr
    gateway = var.network_gateway
    domain  = "jclee.me"
  }
}


# =============================================================================
# LOCAL VALIDATION
# =============================================================================

locals {
  node_name = var.node_name

  # Container sizing (IP/VMID from module.hosts, sizing here)
  container_sizing = {
    runner    = { memory = 2048, cores = 2, disk_size = 32, description = "GitHub Actions Self-hosted Runner" }
    traefik   = { memory = 512, cores = 2, disk_size = 8, description = "Traefik Reverse Proxy + Cloudflare Tunnel" }
    grafana   = { memory = 2048, cores = 2, disk_size = 16, description = "Grafana + Loki Observability Stack" }
    elk       = { memory = 12288, cores = 4, disk_size = 64, description = "ELK Stack (Elasticsearch, Logstash, Kibana)" }
    glitchtip = { memory = 2048, cores = 2, disk_size = 32, description = "GlitchTip Error Tracking" }
  }

  # Merge host inventory with sizing (containers only, exclude VMs and hypervisor)
  containers = {
    for name, sizing in local.container_sizing : name => merge(
      {
        vmid     = module.hosts.hosts[name].vmid
        hostname = name
        ip       = module.hosts.hosts[name].ip
      },
      sizing
    )
  }

  # Validation: Ensure all VMIDs are within managed range
  vmid_validation = {
    for k, v in local.containers : k => {
      in_range = v.vmid >= var.managed_vmid_range.min && v.vmid <= var.managed_vmid_range.max
      message  = "Container '${k}' VMID ${v.vmid} is outside managed range (${var.managed_vmid_range.min}-${var.managed_vmid_range.max})"
    }
  }

  # Validation: Ensure all IPs are in the correct subnet
  ip_validation = {
    for k, v in local.containers : k => {
      in_subnet = can(cidrhost(var.network_cidr, parseint(split(".", v.ip)[3], 10)))
      message   = "Container '${k}' IP ${v.ip} is outside network ${var.network_cidr}"
    }
  }

  # Validation: Ensure memory meets minimum requirements
  memory_validation = {
    for k, v in local.containers : k => {
      sufficient = v.memory >= 256
      divisible  = v.memory % 256 == 0
      message    = "Container '${k}' memory ${v.memory}MB must be >= 256MB and divisible by 256"
    }
  }
}

# Validation checks using check blocks (Terraform 1.5+)
check "vmid_range" {
  assert {
    condition = alltrue([
      for k, v in local.vmid_validation : v.in_range
    ])
    error_message = join("\n", [
      for k, v in local.vmid_validation : v.message if !v.in_range
    ])
  }
}

check "ip_subnet" {
  assert {
    condition = alltrue([
      for k, v in local.ip_validation : v.in_subnet
    ])
    error_message = join("\n", [
      for k, v in local.ip_validation : v.message if !v.in_subnet
    ])
  }
}

check "memory_requirements" {
  assert {
    condition = alltrue([
      for k, v in local.memory_validation : v.sufficient && v.divisible
    ])
    error_message = join("\n", [
      for k, v in local.memory_validation : v.message if !(v.sufficient && v.divisible)
    ])
  }
}

# =============================================================================
# CONTAINER MODULES
# =============================================================================

module "lxc" {
  source   = "../modules/proxmox/lxc"
  for_each = local.containers

  node_name        = local.node_name
  vmid             = each.value.vmid
  hostname         = each.value.hostname
  ip_address       = each.value.ip
  memory           = each.value.memory
  cores            = each.value.cores
  disk_size        = each.value.disk_size
  description      = each.value.description
  privileged       = lookup(each.value, "privileged", false)
  network_gateway  = var.network_gateway
  dns_servers      = var.dns_servers
  default_swap     = var.default_swap
  datastore_id     = var.datastore_id
  managed_vmid_min = var.managed_vmid_range.min
  managed_vmid_max = var.managed_vmid_range.max
  ssh_public_keys  = var.ssh_public_keys
}

# =============================================================================
# VIRTUAL MACHINES (VMs)
# =============================================================================

# =============================================================================
# CLOUD-INIT CONFIGURATION FILES
# =============================================================================
# These files are managed externally and uploaded to pve:/var/lib/vz/snippets/
# Using data source to reference existing files rather than managing upload
# (Provider SSH auth to pve not configured)

locals {
  cloud_init_files = {
    # sandbox: Commented out — VM was manually created with non-standard 'dfge'
    # datastore. bpg/proxmox provider GRPC crashes on import. Will re-add when
    # VM is recreated from template on standard storage.
    # sandbox = "local:snippets/sandbox-user-data.yaml"
    mcphub = "local:snippets/mcphub-user-data.yaml"
  }
}

# =============================================================================
# SANDBOX VM (220) - Development/Test Environment
# =============================================================================
# TEMPORARILY DISABLED: VM 220 was manually created with non-standard 'dfge'
# datastore. The bpg/proxmox provider GRPC plugin crashes during import
# (ReadResource failure). This resource will be re-enabled when the VM is
# recreated from template 9000 on standard 'local-lvm' storage.
#
# resource "proxmox_virtual_environment_vm" "sandbox" {
#   name        = "sandbox"
#   description = "Sandbox VM for development testing and experiments"
#   node_name   = local.node_name
#   vm_id       = 220
#
#   clone {
#     vm_id = 9000
#     full  = true
#   }
#
#   agent {
#     enabled = true
#   }
#
#   cpu {
#     cores = 2
#     type  = "host"
#   }
#
#   memory {
#     dedicated = 8192
#   }
#
#   disk {
#     datastore_id = var.datastore_id
#     interface    = "scsi0"
#     size         = 50
#     iothread     = true
#   }
#
#   network_device {
#     bridge = "vmbr0"
#   }
#
#   initialization {
#     datastore_id      = "local"
#     user_data_file_id = local.cloud_init_files.sandbox
#
#     ip_config {
#       ipv4 {
#         address = "${module.hosts.hosts.sandbox.ip}/24"
#         gateway = var.network_gateway
#       }
#     }
#
#     dns {
#       servers = [var.network_gateway, "8.8.8.8"]
#     }
#   }
#
#   operating_system {
#     type = "l26"
#   }
#
#   machine = "q35"
#   bios    = "ovmf"
#
#   on_boot = true
#
#   lifecycle {
#     ignore_changes = [
#       network_device[0].mac_address,
#       agent,
#       operating_system,
#       disk[0].datastore_id,
#     ]
#   }
# }

# =============================================================================
# MCPHUB VM (112) - MCPHub Server
# =============================================================================

resource "proxmox_virtual_environment_vm" "mcphub" {
  name        = "mcphub"
  description = "MCPHub - Unified MCP Server Gateway"
  node_name   = local.node_name
  vm_id       = 112

  bios = "seabios"

  # Clone from Ubuntu 24.04 cloud-init template
  clone {
    vm_id = 9000
    full  = true
  }

  agent {
    enabled = true
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 6144
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "scsi0"
    size         = 32
    iothread     = true
  }

  network_device {
    bridge = "vmbr0"
  }

  initialization {
    datastore_id      = "local"
    user_data_file_id = local.cloud_init_files.mcphub

    ip_config {
      ipv4 {
        address = "${module.hosts.hosts.mcphub.ip}/24"
        gateway = var.network_gateway
      }
    }

    dns {
      servers = [var.network_gateway, "8.8.8.8"]
    }
  }

  operating_system {
    type = "l26"
  }

  on_boot = true

  lifecycle {
    ignore_changes = [
      network_device[0].mac_address,
      agent,
      operating_system,
      disk[0].datastore_id,
    ]
  }
}

# =============================================================================
# =============================================================================
# OUTPUTS
# =============================================================================

output "nodes" {
  description = "List of Proxmox nodes"
  value       = data.proxmox_virtual_environment_nodes.nodes.names
}

output "container_ips" {
  description = "Container IP addresses"
  value = {
    for k, v in module.lxc : k => v.ip_address
  }
}

output "container_ids" {
  description = "Container VMIDs"
  value = {
    for k, v in module.lxc : k => v.vmid
  }
}

output "container_status" {
  description = "Container deployment status"
  value = {
    for k, v in module.lxc : k => {
      vmid    = v.vmid
      started = v.status.started
      node    = v.status.node
    }
  }
}

output "validation_summary" {
  description = "Configuration validation summary"
  value = {
    node_valid       = contains(data.proxmox_virtual_environment_nodes.nodes.names, local.node_name)
    containers_count = length(local.containers)
    vmid_range       = "${var.managed_vmid_range.min}-${var.managed_vmid_range.max}"
    network_cidr     = var.network_cidr
  }
}


module "vm_config" {
  source = "../modules/proxmox/vm-config"

  deploy_vm_configs = var.deploy_vm_configs
  ssh_user          = "jclee"

  vms = {
    # sandbox: Disabled — see sandbox VM resource block comment above
    # sandbox = {
    #   vmid       = module.hosts.hosts.sandbox.vmid
    #   hostname   = "sandbox"
    #   ip_address = module.hosts.hosts.sandbox.ip
    #   deploy     = var.deploy_vm_configs
    #
    #   cloud_init = {
    #     packages = [
    #       "qemu-guest-agent",
    #       "curl",
    #       "vim",
    #       "git",
    #       "gnupg",
    #     ]
    #     runcmd = [
    #       "systemctl enable qemu-guest-agent",
    #       "systemctl start qemu-guest-agent",
    #     ]
    #   }
    # }

    mcphub = {
      vmid       = module.hosts.hosts.mcphub.vmid
      hostname   = "mcphub"
      ip_address = module.hosts.hosts.mcphub.ip
      deploy     = var.deploy_vm_configs

      cloud_init = {
        packages = [
          "qemu-guest-agent",
          "curl",
          "vim",
          "git",
          "htop",
          "docker.io",
          "docker-compose-v2"
        ]
        runcmd = [
          "systemctl enable qemu-guest-agent",
          "systemctl start qemu-guest-agent",
          "systemctl enable docker",
          "systemctl start docker",
          "mkdir -p /opt/mcphub",
          "cd /opt/mcphub && docker compose build && docker compose up -d"
        ]
        write_files = [
          {
            path        = "/opt/mcphub/docker-compose.yml"
            content     = module.config_renderer.rendered_configs["mcphub_docker_compose"]
            permissions = "0644"
            owner       = "root:root"
          },
          {
            path        = "/opt/mcphub/mcp_settings.json"
            content     = module.config_renderer.rendered_configs["mcphub_mcp_settings"]
            permissions = "0644"
            owner       = "root:root"
          },
          {
            path        = "/opt/mcphub/Dockerfile.proxmox"
            content     = file("${path.module}/../112-mcphub/Dockerfile.proxmox")
            permissions = "0644"
            owner       = "root:root"
          },
          {
            path        = "/opt/mcphub/Dockerfile.playwright"
            content     = file("${path.module}/../112-mcphub/Dockerfile.playwright")
            permissions = "0644"
            owner       = "root:root"
          }
        ]
      }
    }
  }
}

module "lxc_config" {
  source = "../modules/proxmox/lxc-config"

  deploy_lxc_configs = var.deploy_lxc_configs
  mcp_host           = module.hosts.hosts.mcphub.ip

  lxc_containers = {
    traefik = {
      vmid       = module.hosts.hosts.traefik.vmid
      hostname   = "traefik"
      ip_address = module.hosts.hosts.traefik.ip
      deploy     = var.deploy_lxc_configs

      config_files = {
        "traefik.yml" = {
          path    = "/etc/traefik/traefik.yml"
          content = file("${path.module}/../102-traefik/config/traefik.yml")
        }
        "traefik-elk.yml" = {
          path    = "/etc/traefik/dynamic/elk.yml"
          content = module.config_renderer.rendered_configs.traefik_elk
        }
        "traefik-glitchtip.yml" = {
          path    = "/etc/traefik/dynamic/glitchtip.yml"
          content = module.config_renderer.rendered_configs.traefik_glitchtip
        }
        "traefik-mcphub.yml" = {
          path    = "/etc/traefik/dynamic/mcphub.yml"
          content = module.config_renderer.rendered_configs.traefik_mcphub
        }
        "traefik-n8n.yml" = {
          path    = "/etc/traefik/dynamic/n8n.yml"
          content = module.config_renderer.rendered_configs.traefik_n8n
        }
        "traefik-synology.yml" = {
          path    = "/etc/traefik/dynamic/synology.yml"
          content = module.config_renderer.rendered_configs.traefik_synology
        }
        "traefik-archon.yml" = {
          path    = "/etc/traefik/dynamic/archon.yml"
          content = module.config_renderer.rendered_configs.traefik_archon
        }
        "traefik-supabase.yml" = {
          path    = "/etc/traefik/dynamic/supabase.yml"
          content = module.config_renderer.rendered_configs.traefik_supabase
        }
      }
    }

    grafana = {
      vmid       = module.hosts.hosts.grafana.vmid
      hostname   = "grafana"
      ip_address = module.hosts.hosts.grafana.ip
      deploy     = var.deploy_lxc_configs

      config_files = {
        "prometheus.yml" = {
          path    = "/etc/prometheus/prometheus.yml"
          content = module.config_renderer.rendered_configs.prometheus
        }
        "grafana-datasources.yml" = {
          path    = "/etc/grafana/provisioning/datasources/datasources.yml"
          content = module.config_renderer.rendered_configs.grafana_datasources
        }
      }

      systemd_services = {
        prometheus = {
          description = "Prometheus Monitoring"
          exec_start  = "/usr/bin/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/var/lib/prometheus --web.listen-address=0.0.0.0:9090"
          user        = "prometheus"
          restart     = "always"
          restart_sec = 5
        }
      }
    }

    elk = {
      vmid       = module.hosts.hosts.elk.vmid
      hostname   = "elk"
      ip_address = module.hosts.hosts.elk.ip
      deploy     = var.deploy_lxc_configs

      docker_compose = {
        path    = "/opt/elk/docker-compose.yml"
        content = module.config_renderer.rendered_configs.elk_docker_compose
      }

      config_files = {
        "logstash.conf" = {
          path    = "/opt/elk/config/logstash.conf"
          content = module.config_renderer.rendered_configs.elk_logstash_conf
        }
        "logstash.yml" = {
          path    = "/opt/elk/config/logstash.yml"
          content = module.config_renderer.rendered_configs.elk_logstash_yml
        }
        "ilm-policy.json" = {
          path    = "/opt/elk/config/ilm-policy.json"
          content = module.config_renderer.rendered_configs.elk_ilm_policy
        }
        "setup-ilm.sh" = {
          path    = "/opt/elk/scripts/setup-ilm.sh"
          content = module.config_renderer.rendered_configs.elk_setup_ilm
        }
      }
    }

    glitchtip = {
      vmid       = module.hosts.hosts.glitchtip.vmid
      hostname   = "glitchtip"
      ip_address = module.hosts.hosts.glitchtip.ip
      deploy     = var.deploy_lxc_configs

      docker_compose = {
        path    = "/opt/glitchtip/docker-compose.yml"
        content = module.config_renderer.rendered_configs.glitchtip_docker_compose
      }

      config_files = {
        "glitchtip.env" = {
          path    = "/opt/glitchtip/glitchtip.env"
          content = module.config_renderer.rendered_configs.glitchtip_env
        }
      }
    }
  }
}

output "vm_configs" {
  description = "VM configuration paths"
  value       = module.vm_config.vm_configs
}

output "lxc_configs" {
  description = "LXC configuration paths"
  value       = module.lxc_config.lxc_configs
}

# =============================================================================
# VAULT SECRETS
# =============================================================================

module "vault_secrets" {
  source = "../modules/shared/vault-secrets"
}

# =============================================================================
# CONFIG RENDERER - Centralized Config Generation
# =============================================================================

module "config_renderer" {
  source = "../modules/proxmox/config-renderer"

  template_vars = merge(module.env_config.template_vars, module.vault_secrets.secrets)
  output_dir    = "${path.module}/configs/rendered"

  template_files = {
    grafana_datasources = {
      source = "${path.module}/../104-grafana/templates/grafana-datasources.yml.tftpl"
      output = "grafana-datasources.yml"
    }
    prometheus = {
      source = "${path.module}/../104-grafana/templates/prometheus.yml.tftpl"
      output = "prometheus.yml"
    }
    traefik_elk = {
      source = "${path.module}/../102-traefik/templates/traefik-elk.yml.tftpl"
      output = "traefik-elk.yml"
    }
    traefik_glitchtip = {
      source = "${path.module}/../102-traefik/templates/glitchtip.yml.tftpl"
      output = "traefik/glitchtip.yml"
    }

    filebeat_elk = {
      source = "${path.module}/../105-elk/templates/filebeat.yml.tftpl"
      output = "elk/filebeat.yml"
    }
    filebeat_runner = {
      source = "${path.module}/../101-runner/templates/filebeat.yml.tftpl"
      output = "runner/filebeat.yml"
    }
    filebeat_traefik = {
      source = "${path.module}/../102-traefik/templates/filebeat.yml.tftpl"
      output = "traefik/filebeat.yml"
    }
    filebeat_grafana = {
      source = "${path.module}/../104-grafana/templates/filebeat.yml.tftpl"
      output = "grafana/filebeat.yml"
    }
    filebeat_glitchtip = {
      source = "${path.module}/../106-glitchtip/templates/filebeat.yml.tftpl"
      output = "glitchtip/filebeat.yml"
    }
    filebeat_supabase = {
      source = "${path.module}/../107-supabase/templates/filebeat.yml.tftpl"
      output = "supabase/filebeat.yml"
    }
    filebeat_mcphub = {
      source = "${path.module}/../112-mcphub/templates/filebeat.yml.tftpl"
      output = "mcphub/filebeat.yml"
    }
    elk_docker_compose = {
      source = "${path.module}/../105-elk/templates/docker-compose.yml.tftpl"
      output = "elk/docker-compose.yml"
    }
    elk_logstash_conf = {
      source = "${path.module}/../105-elk/templates/logstash.conf.tftpl"
      output = "elk/logstash.conf"
    }
    elk_logstash_yml = {
      source = "${path.module}/../105-elk/templates/logstash.yml.tftpl"
      output = "elk/logstash.yml"
    }
    elk_ilm_policy = {
      source = "${path.module}/../105-elk/templates/ilm-policy.json.tftpl"
      output = "elk/ilm-policy.json"
    }
    elk_setup_ilm = {
      source = "${path.module}/../105-elk/templates/setup-ilm.sh.tftpl"
      output = "elk/setup-ilm.sh"
    }
    glitchtip_docker_compose = {
      source = "${path.module}/../106-glitchtip/templates/docker-compose.yml.tftpl"
      output = "glitchtip/docker-compose.yml"
    }
    glitchtip_env = {
      source = "${path.module}/../106-glitchtip/templates/glitchtip.env.tftpl"
      output = "glitchtip/glitchtip.env"
    }
    mcphub_docker_compose = {
      source = "${path.module}/../112-mcphub/templates/docker-compose.yml.tftpl"
      output = "mcphub/docker-compose.yml"
    }
    mcphub_mcp_settings = {
      source = "${path.module}/../112-mcphub/templates/mcp_settings.json.tftpl"
      output = "mcphub/mcp_settings.json"
    }
    traefik_mcphub = {
      source = "${path.module}/../102-traefik/templates/mcphub.yml.tftpl"
      output = "traefik/mcphub.yml"
    }
    traefik_n8n = {
      source = "${path.module}/../102-traefik/templates/n8n.yml.tftpl"
      output = "traefik/n8n.yml"
    }
    traefik_synology = {
      source = "${path.module}/../102-traefik/templates/synology.yml.tftpl"
      output = "traefik/synology.yml"
    }
    traefik_archon = {
      source = "${path.module}/../102-traefik/templates/archon.yml.tftpl"
      output = "traefik/archon.yml"
    }
    traefik_supabase = {
      source = "${path.module}/../102-traefik/templates/supabase.yml.tftpl"
      output = "traefik/supabase.yml"
    }
  }
}

output "rendered_configs" {
  description = "Paths to rendered configuration files"
  value       = module.config_renderer.rendered_files
}
