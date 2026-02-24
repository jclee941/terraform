provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = local.effective_proxmox_api_token
  insecure  = var.proxmox_insecure
}

provider "onepassword" {
  service_account_token = trimspace(var.op_service_account_token)
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

# env-config module removed — non-hosts template vars inlined below
# All IP/port refs now use hosts.X.Y directly in templates


# =============================================================================
# LOCAL VALIDATION
# =============================================================================

locals {
  node_name                  = var.node_name
  proxmox_endpoint_no_scheme = trimprefix(var.proxmox_endpoint, "https://")
  proxmox_endpoint_no_slash  = trimsuffix(local.proxmox_endpoint_no_scheme, "/")
  proxmox_endpoint_parts     = split(":", local.proxmox_endpoint_no_slash)
  proxmox_host               = local.proxmox_endpoint_parts[0]
  proxmox_port               = length(local.proxmox_endpoint_parts) > 1 ? local.proxmox_endpoint_parts[1] : "8006"
  proxmox_ssl_mode           = var.proxmox_insecure ? "insecure" : "strict"
  proxmox_api_token_from_1password = trimspace(try(
    module.onepassword_secrets.secrets["proxmox_api_token_value"],
    ""
  ))
  effective_proxmox_api_token = (
    local.proxmox_api_token_from_1password != "" ?
    local.proxmox_api_token_from_1password :
    trimspace(var.proxmox_api_token)
  )
  tunnel_token_from_1password = trimspace(try(
    module.onepassword_secrets.secrets["cloudflare_tunnel_token"],
    ""
  ))
  effective_homelab_tunnel_token = (
    local.tunnel_token_from_1password != "" ?
    local.tunnel_token_from_1password :
    trimspace(var.homelab_tunnel_token)
  )

  infrastructure_nodes = [
    for name, host in module.hosts.hosts : {
      name = name
      ip   = host.ip
      vmid = host.vmid
    }
    if !contains(host.roles, "hypervisor")
  ]

  mcp_catalog = jsondecode(file("${path.module}/../112-mcphub/mcp_servers.json"))
  mcp_hub_servers = {
    for k, v in local.mcp_catalog.servers : k => v
    if v.location == "hub"
  }
  mcp_hub_stdio_servers = {
    for k, v in local.mcp_hub_servers : k => v
    if lookup(v, "transport", "stdio") == "stdio"
  }
  mcp_hub_sse_servers = {
    for k, v in local.mcp_hub_servers : k => v
    if lookup(v, "transport", "stdio") == "sse" && !contains(keys(v), "url")
  }
  mcp_hub_external_sse_servers = {
    for k, v in local.mcp_hub_servers : k => v
    if lookup(v, "transport", "stdio") == "sse" && contains(keys(v), "url")
  }
  mcp_hub_http_servers = {
    for k, v in local.mcp_hub_servers : k => v
    if lookup(v, "transport", "stdio") == "http"
  }

  # Container sizing (IP/VMID from module.hosts, sizing here)
  # Memory budget: Optimized with per-container swap for efficient memory utilization
  # Strategy: Reduce dedicated RAM, use swap for cold pages (idle JVM, DB buffers)
  # Total dedicated: 16640 MB (16.3 GB) + swap: 9472 MB (9.3 GB) = 26112 MB effective
  container_sizing = {
    runner    = { memory = 1024, swap = 512, cores = 2, disk_size = 32, description = "GitHub Actions Self-hosted Runner" }
    traefik   = { memory = 512, swap = 256, cores = 2, disk_size = 8, description = "Traefik Reverse Proxy + Cloudflare Tunnel" }
    grafana   = { memory = 768, swap = 512, cores = 2, disk_size = 16, description = "Grafana + Prometheus Observability Stack" }
    elk       = { memory = 8192, swap = 4096, cores = 4, disk_size = 64, description = "ELK Stack (Elasticsearch, Logstash, Kibana)" }
    glitchtip = { memory = 1024, swap = 512, cores = 2, disk_size = 32, description = "GlitchTip Error Tracking" }
    supabase  = { memory = 3072, swap = 2048, cores = 4, disk_size = 64, description = "Supabase Backend-as-a-Service" }
    archon    = { memory = 2048, swap = 1536, cores = 4, disk_size = 20, description = "Archon AI Knowledge Management + MCP Server" }
    coredns   = { memory = 256, swap = 256, cores = 1, disk_size = 4, description = "CoreDNS Split DNS Resolver" }
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
      swap_valid = v.swap >= 0 && v.swap <= v.memory * 2
      message    = "Container '${k}' memory ${v.memory}MB must be >= 256MB and divisible by 256, swap ${v.swap}MB must be 0..${v.memory * 2}MB"
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
      for k, v in local.memory_validation : v.sufficient && v.divisible && v.swap_valid
    ])
    error_message = join("\n", [
      for k, v in local.memory_validation : v.message if !(v.sufficient && v.divisible && v.swap_valid)
    ])
  }
}

check "proxmox_provider_token_required" {
  assert {
    condition     = length(local.effective_proxmox_api_token) > 0
    error_message = "Proxmox provider token is required. Set 1Password secret key 'proxmox_api_token_value' (preferred) or provide var.proxmox_api_token override."
  }
}

check "mcphub_required_secrets" {
  assert {
    condition = alltrue([
      for k in [
        "mcphub_admin_password",
        "mcphub_n8n_mcp_api_key",
        "mcphub_op_service_account_token",
        "mcphub_proxmox_token_name",
        "mcphub_proxmox_token_value",
      ] : length(trimspace(lookup(module.onepassword_secrets.secrets, k, ""))) > 0
    ])
    error_message = "MCPHub required 1Password fields are missing. Required keys: mcphub_admin_password, mcphub_n8n_mcp_api_key, mcphub_op_service_account_token, mcphub_proxmox_token_name, mcphub_proxmox_token_value"
  }
}

check "deploy_ssh_key_required" {
  assert {
    condition     = !(var.deploy_lxc_configs || var.deploy_vm_configs) || length(trimspace(lookup(module.onepassword_secrets.secrets, "proxmox_ssh_private_key", ""))) > 0
    error_message = "deploy_lxc_configs/deploy_vm_configs requires onepassword secret key 'proxmox_ssh_private_key' in item 'proxmox' section 'secrets'."
  }
}

check "no_placeholder_secrets" {
  assert {
    condition     = length(local.placeholder_template_secret_keys) == 0
    error_message = "1Password secrets contain placeholder values that must be replaced with real credentials: ${join(", ", local.placeholder_template_secret_keys)}"
  }
}

check "no_placeholder_metadata" {
  assert {
    condition     = length(local.placeholder_template_metadata_keys) == 0
    error_message = "1Password metadata contain placeholder values consumed by templates: ${join(", ", local.placeholder_template_metadata_keys)}"
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
  swap             = each.value.swap
  cores            = each.value.cores
  disk_size        = each.value.disk_size
  description      = each.value.description
  privileged       = lookup(each.value, "privileged", false)
  network_gateway  = var.network_gateway
  dns_servers      = var.dns_servers
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
    mcphub  = "local:snippets/mcphub-user-data.yaml"
    youtube = "local:snippets/youtube-user-data.yaml"
  }
  vm_definitions = {
    mcphub = {
      vmid        = 112
      description = "MCPHub - Unified MCP Server Gateway"
      memory      = 6144
      cores       = 2
      disk_size   = 32
    }
    youtube = {
      vmid        = 220
      description = "YouTube Media Server"
      memory      = 8192
      cores       = 2
      disk_size   = 50
      bios        = "ovmf"
      machine     = "q35"
    }
  }
}

# =============================================================================
# MCPHUB VM (112) - MCPHub Server
# =============================================================================

module "vm" {
  source   = "../modules/proxmox/vm"
  for_each = local.vm_definitions

  node_name        = local.node_name
  vmid             = each.value.vmid
  hostname         = each.key
  description      = each.value.description
  ip_address       = module.hosts.hosts[each.key].ip
  memory           = each.value.memory
  cores            = each.value.cores
  disk_size        = each.value.disk_size
  bios             = try(each.value.bios, "seabios")
  machine          = try(each.value.machine, "pc")
  network_gateway  = var.network_gateway
  dns_servers      = var.dns_servers
  datastore_id     = var.datastore_id
  managed_vmid_min = var.managed_vmid_range.min
  managed_vmid_max = var.managed_vmid_range.max

  cloud_init_file_id = try(local.cloud_init_files[each.key], null)
}

moved {
  from = proxmox_virtual_environment_vm.mcphub
  to   = module.vm["mcphub"].proxmox_virtual_environment_vm.this
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
  ssh_user          = "root"
  ssh_private_key   = lookup(module.onepassword_secrets.secrets, "proxmox_ssh_private_key", "")

  vms = {
    youtube = {
      vmid       = module.hosts.hosts.youtube.vmid
      hostname   = "youtube"
      ip_address = module.hosts.hosts.youtube.ip
      deploy     = var.deploy_vm_configs

      cloud_init = {
        packages = [
          "qemu-guest-agent",
          "curl",
          "vim",
          "git",
          "gnupg",
        ]
        runcmd = [
          "systemctl enable qemu-guest-agent",
          "systemctl start qemu-guest-agent",
        ]
      }
    }

    mcphub = {
      vmid           = module.hosts.hosts.mcphub.vmid
      hostname       = "mcphub"
      ip_address     = module.hosts.hosts.mcphub.ip
      deploy         = var.deploy_vm_configs
      setup_filebeat = true

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
          "mkdir -p /opt/n8n",
          "systemctl daemon-reload",
          "cd /opt/mcphub && docker compose build && docker compose up -d",
          "cd /opt/n8n && docker compose up -d"
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
          },
          {
            path        = "/opt/mcphub/.env"
            content     = module.config_renderer.rendered_configs["mcphub_env"]
            permissions = "0600"
            owner       = "root:root"
          },
          {
            path        = "/etc/filebeat/filebeat.yml"
            content     = module.config_renderer.rendered_configs["mcphub_filebeat"]
            permissions = "0644"
            owner       = "root:root"
          },
          {
            path        = "/opt/n8n/docker-compose.yml"
            content     = module.config_renderer.rendered_configs["mcphub_n8n_docker_compose"]
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
  ssh_user           = "root"
  ssh_private_key    = lookup(module.onepassword_secrets.secrets, "proxmox_ssh_private_key", "")

  lxc_containers = {
    runner = {
      vmid           = module.hosts.hosts.runner.vmid
      hostname       = "runner"
      ip_address     = module.hosts.hosts.runner.ip
      deploy         = var.deploy_lxc_configs
      setup_filebeat = true

      config_files = {
        "filebeat.yml" = {
          path    = "/etc/filebeat/filebeat.yml"
          content = module.config_renderer.rendered_configs.runner_filebeat
        }
      }
    }

    traefik = {
      vmid           = module.hosts.hosts.traefik.vmid
      hostname       = "traefik"
      ip_address     = module.hosts.hosts.traefik.ip
      deploy         = var.deploy_lxc_configs
      setup_filebeat = true

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
        "traefik-grafana.yml" = {
          path    = "/etc/traefik/dynamic/grafana.yml"
          content = module.config_renderer.rendered_configs.traefik_grafana
        }
        "traefik-nas.yml" = {
          path    = "/etc/traefik/dynamic/nas.yml"
          content = module.config_renderer.rendered_configs.traefik_nas
        }
        "traefik-opencode.yml" = {
          path    = "/etc/traefik/dynamic/opencode.yml"
          content = module.config_renderer.rendered_configs.traefik_opencode
        }
        "traefik-supabase.yml" = {
          path    = "/etc/traefik/dynamic/supabase.yml"
          content = module.config_renderer.rendered_configs.traefik_supabase
        }
        "filebeat.yml" = {
          path    = "/etc/filebeat/filebeat.yml"
          content = module.config_renderer.rendered_configs.traefik_filebeat
        }
        "cloudflared-docker-compose.yml" = {
          path    = "/opt/cloudflared/docker-compose.yml"
          content = module.config_renderer.rendered_configs.traefik_cloudflared
        }
      }
    }

    grafana = {
      vmid           = module.hosts.hosts.grafana.vmid
      hostname       = "grafana"
      ip_address     = module.hosts.hosts.grafana.ip
      deploy         = var.deploy_lxc_configs
      setup_filebeat = true

      config_files = {
        "prometheus.yml" = {
          path    = "/etc/prometheus/prometheus.yml"
          content = module.config_renderer.rendered_configs.prometheus
        }
        "grafana-datasources.yml" = {
          path    = "/etc/grafana/provisioning/datasources/datasources.yml"
          content = module.config_renderer.rendered_configs.grafana_datasources
        }
        "filebeat.yml" = {
          path    = "/etc/filebeat/filebeat.yml"
          content = module.config_renderer.rendered_configs.grafana_filebeat
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
      vmid           = module.hosts.hosts.elk.vmid
      hostname       = "elk"
      ip_address     = module.hosts.hosts.elk.ip
      deploy         = var.deploy_lxc_configs
      setup_filebeat = true

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
        "filebeat.yml" = {
          path    = "/etc/filebeat/filebeat.yml"
          content = module.config_renderer.rendered_configs.elk_filebeat
        }
        "Dockerfile.logstash" = {
          path    = "/opt/elk/config/Dockerfile.logstash"
          content = module.config_renderer.rendered_configs.elk_dockerfile_logstash
        }
      }
    }

    glitchtip = {
      vmid           = module.hosts.hosts.glitchtip.vmid
      hostname       = "glitchtip"
      ip_address     = module.hosts.hosts.glitchtip.ip
      deploy         = var.deploy_lxc_configs
      setup_filebeat = true

      docker_compose = {
        path    = "/opt/glitchtip/docker-compose.yml"
        content = module.config_renderer.rendered_configs.glitchtip_docker_compose
      }

      config_files = {
        "glitchtip.env" = {
          path    = "/opt/glitchtip/glitchtip.env"
          content = module.config_renderer.rendered_configs.glitchtip_env
        }
        "filebeat.yml" = {
          path    = "/etc/filebeat/filebeat.yml"
          content = module.config_renderer.rendered_configs.glitchtip_filebeat
        }
      }
    }

    supabase = {
      vmid           = module.hosts.hosts.supabase.vmid
      hostname       = "supabase"
      ip_address     = module.hosts.hosts.supabase.ip
      deploy         = var.deploy_lxc_configs
      setup_filebeat = true

      docker_compose = {
        path    = "/opt/supabase/docker-compose.yml"
        content = module.config_renderer.rendered_configs.supabase_docker_compose
      }

      config_files = {
        "supabase.env" = {
          path    = "/opt/supabase/.env"
          content = module.config_renderer.rendered_configs.supabase_env
        }
        "filebeat.yml" = {
          path    = "/etc/filebeat/filebeat.yml"
          content = module.config_renderer.rendered_configs.supabase_filebeat
        }
      }
    }

    archon = {
      vmid           = module.hosts.hosts.archon.vmid
      hostname       = "archon"
      ip_address     = module.hosts.hosts.archon.ip
      deploy         = var.deploy_lxc_configs
      setup_filebeat = true

      docker_compose = {
        path    = "/opt/archon/docker-compose.yml"
        content = module.config_renderer.rendered_configs.archon_docker_compose
      }

      config_files = {
        "archon.env" = {
          path    = "/opt/archon/.env"
          content = module.config_renderer.rendered_configs.archon_env
        }
        "filebeat.yml" = {
          path    = "/etc/filebeat/filebeat.yml"
          content = module.config_renderer.rendered_configs.archon_filebeat
        }
      }
    }

    coredns = {
      vmid           = module.hosts.hosts.coredns.vmid
      hostname       = "coredns"
      ip_address     = module.hosts.hosts.coredns.ip
      deploy         = var.deploy_lxc_configs
      setup_filebeat = true

      docker_compose = {
        path    = "/opt/coredns/docker-compose.yml"
        content = module.config_renderer.rendered_configs.coredns_docker_compose
      }

      config_files = {
        "Corefile" = {
          path    = "/opt/coredns/Corefile"
          content = module.config_renderer.rendered_configs.coredns_corefile
        }
        "filebeat.yml" = {
          path    = "/etc/filebeat/filebeat.yml"
          content = module.config_renderer.rendered_configs.coredns_filebeat
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
  sensitive   = true
}

# =============================================================================
# 1PASSWORD SECRETS
# =============================================================================

module "onepassword_secrets" {
  source     = "../modules/shared/onepassword-secrets"
  vault_name = var.onepassword_vault_name
}

locals {
  required_template_secret_keys = [
    "elk_elastic_password",
    "elk_kibana_password",
    "github_personal_access_token",
    "glitchtip_api_token",
    "glitchtip_django_secret_key",
    "glitchtip_postgres_password",
    "glitchtip_redis_password",
    "mcphub_admin_password",
    "mcphub_n8n_mcp_api_key",
    "mcphub_op_service_account_token",
    "mcphub_proxmox_token_name",
    "mcphub_proxmox_token_value",
    "openai_api_key",
    "proxmox_ssh_private_key",
    "slack_mcp_xoxb_token",
    "slack_mcp_xoxp_token",
    "supabase_anon_key",
    "supabase_dashboard_password",
    "supabase_db_password",
    "supabase_jwt_secret",
    "supabase_service_role_key",
  ]

  missing_required_template_secret_keys = [
    for k in local.required_template_secret_keys :
    k if length(trimspace(lookup(module.onepassword_secrets.secrets, k, ""))) == 0
  ]

  placeholder_template_secret_keys = [
    for k in local.required_template_secret_keys :
    k if can(regex("(?i)placeholder", lookup(module.onepassword_secrets.secrets, k, "")))
  ]

  # Metadata keys consumed by service templates (must not be placeholder)
  required_template_metadata_keys = [
    "supabase_url",
    "supabase_dashboard_username",
  ]

  placeholder_template_metadata_keys = [
    for k in local.required_template_metadata_keys :
    k if can(regex("(?i)placeholder", lookup(module.onepassword_secrets.metadata, k, "")))
  ]
}

# =============================================================================
# CONFIG RENDERER - Centralized Config Generation
# =============================================================================

locals {
  # Service template registry: each service dir maps to its output prefix and template files.
  _svc_tpl = {
    "101-runner" = { prefix = "runner", files = {
      filebeat = "filebeat.yml.tftpl"
    } }
    "102-traefik" = { prefix = "traefik", files = {
      glitchtip   = "glitchtip.yml.tftpl"
      mcphub      = "mcphub.yml.tftpl"
      n8n         = "n8n.yml.tftpl"
      synology    = "synology.yml.tftpl"
      archon      = "archon.yml.tftpl"
      supabase    = "supabase.yml.tftpl"
      grafana     = "grafana.yml.tftpl"
      nas         = "nas.yml.tftpl"
      opencode    = "opencode.yml.tftpl"
      filebeat    = "filebeat.yml.tftpl"
      cloudflared = "cloudflared-docker-compose.yml.tftpl"
    } }
    "103-coredns" = { prefix = "coredns", files = {
      corefile       = "Corefile.tftpl"
      docker_compose = "docker-compose.yml.tftpl"
      filebeat       = "filebeat.yml.tftpl"
    } }
    "104-grafana" = { prefix = "grafana", files = {
      filebeat = "filebeat.yml.tftpl"
    } }
    "105-elk" = { prefix = "elk", files = {
      filebeat            = "filebeat.yml.tftpl"
      docker_compose      = "docker-compose.yml.tftpl"
      logstash_conf       = "logstash.conf.tftpl"
      logstash_yml        = "logstash.yml.tftpl"
      ilm_policy          = "ilm-policy.json.tftpl"
      setup_ilm           = "setup-ilm.sh.tftpl"
      dockerfile_logstash = "Dockerfile.logstash.tftpl"
    } }
    "106-glitchtip" = { prefix = "glitchtip", files = {
      filebeat       = "filebeat.yml.tftpl"
      docker_compose = "docker-compose.yml.tftpl"
      env            = "glitchtip.env.tftpl"
    } }
    "107-supabase" = { prefix = "supabase", files = {
      filebeat       = "filebeat.yml.tftpl"
      docker_compose = "docker-compose.yml.tftpl"
      env            = ".env.tftpl"
    } }
    "108-archon" = { prefix = "archon", files = {
      filebeat       = "filebeat.yml.tftpl"
      docker_compose = "docker-compose.yml.tftpl"
      env            = ".env.tftpl"
    } }
    "112-mcphub" = { prefix = "mcphub", files = {
      filebeat           = "filebeat.yml.tftpl"
      docker_compose     = "docker-compose.yml.tftpl"
      mcp_settings       = "mcp_settings.json.tftpl"
      env                = ".env.tftpl"
      n8n_docker_compose = "docker-compose-n8n.yml.tftpl"
      op_connect_compose = "docker-compose-op-connect.yml.tftpl"
    } }
    "220-youtube" = { prefix = "youtube", files = {
      filebeat = "filebeat.yml.tftpl"
    } }
  }

  service_templates = merge([
    for svc_dir, svc in local._svc_tpl : {
      for name, file in svc.files :
      "${svc.prefix}_${name}" => {
        source = "${path.module}/../${svc_dir}/templates/${file}"
        output = "${svc.prefix}/${trimsuffix(file, ".tftpl")}"
      }
    }
  ]...)

  # Root-level templates that output to the top-level (not in service subdirs).
  root_templates = {
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
  }
}

module "config_renderer" {
  source = "../modules/proxmox/config-renderer"

  template_vars = merge(
    module.onepassword_secrets.secrets,
    module.onepassword_secrets.metadata,
    {
      hosts                = module.hosts.hosts
      domain               = "jclee.me"
      infrastructure_nodes = local.infrastructure_nodes

      elk_version = "8.17.0"

      glitchtip_version          = "v6.0.5"
      glitchtip_postgres_version = "15.16-alpine"
      glitchtip_redis_version    = "7.4.7-alpine"
      mcphub_version             = "0.12.3"

      es_heap                     = "3g"
      logstash_heap               = "512m"
      logstash_dlq_size           = "1024mb"
      elasticsearch_index_pattern = "logs-%%{[service]}-%%{+YYYY.MM.dd}"
      ilm_delete_after            = "30d"
      ilm_policy_name             = "homelab-logs-30d"
      ilm_critical_delete_after   = "90d"
      ilm_ephemeral_delete_after  = "7d"

      prometheus_datasource_uid = "prometheus"
      sla_target_percentage     = "99.9"

      mcp_catalog_json          = jsonencode(local.mcp_catalog)
      mcp_hub_servers_json      = jsonencode(local.mcp_hub_servers)
      mcp_hub_stdio_json        = jsonencode(local.mcp_hub_stdio_servers)
      mcp_hub_sse_json          = jsonencode(local.mcp_hub_sse_servers)
      mcp_hub_external_sse_json = jsonencode(local.mcp_hub_external_sse_servers)
      mcp_hub_http_json         = jsonencode(local.mcp_hub_http_servers)
      mcp_host                  = local.mcp_catalog.mcp_host
      proxmox_host              = local.proxmox_host
      proxmox_port              = local.proxmox_port
      proxmox_ssl_mode          = local.proxmox_ssl_mode
      homelab_tunnel_token      = local.effective_homelab_tunnel_token
    }
  )
  output_dir = "${path.module}/configs/rendered"

  template_files = merge(
    local.root_templates,
    local.service_templates,
  )
}

output "rendered_configs" {
  description = "Paths to rendered configuration files"
  value       = module.config_renderer.rendered_files
}

output "required_template_secrets_validation" {
  description = "Fail-fast validation for required 1Password secret keys consumed by rendered templates"
  value       = true

  precondition {
    condition = length(local.missing_required_template_secret_keys) == 0
    error_message = format(
      "Missing required 1Password secret keys for template rendering: %s",
      join(
        ", ",
        sort(nonsensitive(local.missing_required_template_secret_keys)),
      ),
    )
  }
}

output "host_inventory" {
  description = "Host inventory map (ip, ports, vmid) for consumption by app workspaces via remote_state"
  value       = module.hosts.hosts
}

output "service_urls" {
  description = "Derived service URLs for consumption by app workspaces (301-github) via remote_state"
  value = {
    grafana_url = "https://grafana.jclee.me"
    n8n_url     = "https://mcphub.jclee.me"
  }
}
