# =============================================================================
# LOCAL VARIABLES
# =============================================================================

# -----------------------------------------------------------------------------
# Proxmox Provider Configuration
# -----------------------------------------------------------------------------

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
    if !contains(host.roles, "hypervisor") && !contains(host.roles, "workstation") && !contains(host.roles, "nas")
  ]

  mcp_catalog = jsondecode(file("${path.module}/../../112-mcphub/mcp_servers.json"))
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
  mcp_hub_external_http_servers = {
    for k, v in local.mcp_hub_servers : k => v
    if lookup(v, "transport", "stdio") == "streamable-http" && contains(keys(v), "url")
  }

  # Container sizing (IP/VMID from module.hosts, sizing here)
  # Memory budget: Optimized with per-container swap for efficient memory utilization
  # Strategy: Reduce dedicated RAM, use swap for cold pages (idle JVM, DB buffers)
  # Total dedicated: 20480 MB (20 GB) + swap: 9984 MB (9.75 GB) = 30464 MB effective
  container_sizing = {
    runner   = { memory = 3072, swap = 1536, cores = 2, disk_size = 32, description = "GitHub Actions CI Runner - Docker executor (3GB RAM)", mount_points = [{ volume = "/mnt/runner-cache", path = "/srv/runner/cache" }] }
    traefik  = { memory = 512, swap = 256, cores = 2, disk_size = 8, description = "Traefik Reverse Proxy + Cloudflare Tunnel" }
    elk      = { memory = 10240, swap = 5120, cores = 4, disk_size = 64, description = "ELK Stack (Elasticsearch, Logstash, Kibana)", mount_points = [{ volume = "/mnt/nas-elk", path = "/mnt/nas-elk" }] }
    coredns  = { memory = 256, swap = 256, cores = 1, disk_size = 4, description = "CoreDNS Split DNS Resolver" }
    n8n      = { memory = 2048, swap = 512, cores = 2, disk_size = 64, description = "n8n Workflow Automation + PostgreSQL" }
    cliproxy = { memory = 512, swap = 256, cores = 2, disk_size = 20, description = "Squid Forward Proxy" }
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

# -----------------------------------------------------------------------------
# Cloud-Init & VM Definitions
# -----------------------------------------------------------------------------

locals {
  cloud_init_files = {
    mcphub  = "local:snippets/mcphub-user-data.yaml"
    youtube = "local:snippets/youtube-user-data.yaml"
  }
  vm_definitions = {
    mcphub = {
      vmid        = 112
      description = "MCPHub - Unified MCP Server Gateway"
      memory      = 10240
      balloon_min = 3072
      cores       = 4
      disk_size   = 32
    }
    youtube = {
      vmid        = 220
      description = "YouTube Media Server"
      memory      = 32768
      balloon_min = 4096
      cores       = 8
      disk_size   = 300
      bios        = "ovmf"
      machine     = "q35"
    }
    jclee-dev = {
      vmid        = 200
      description = "OpenCode Development VM (oc)"
      memory      = 28672
      balloon_min = 4096
      cores       = 8
      disk_size   = 200
      hostname    = "oc"
      bios        = "seabios"
      machine     = "q35"
    }
  }
}

# -----------------------------------------------------------------------------
# 1Password Secret Validation
# -----------------------------------------------------------------------------

locals {
  required_template_secret_keys = [
    "elk_elastic_password",
    "elk_kibana_password",
    "github_personal_access_token",
    "mcphub_admin_password",
    "mcphub_n8n_mcp_api_key",
    "mcphub_op_connect_token",
    "mcphub_op_service_account_token",
    "mcphub_proxmox_token_name",
    "mcphub_proxmox_token_value",
    "n8n_api_key",
    "n8n_encryption_key",
    "n8n_github_token",
    "n8n_postgres_password",
    "proxmox_ssh_private_key",
    "slack_bot_token",
    "telegram_bot_token",
    "traefik_htpasswd_hash",
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
  ]

  placeholder_template_metadata_keys = [
    for k in local.required_template_metadata_keys :
    k if can(regex("(?i)placeholder", lookup(module.onepassword_secrets.metadata, k, "")))
  ]
}

# -----------------------------------------------------------------------------
# Config Renderer — Service Template Registry
# -----------------------------------------------------------------------------

locals {
  # Service template registry: each service dir maps to its output prefix and template files.
  _svc_tpl = {
    "101-runner" = { prefix = "runner", files = {
      filebeat = "filebeat.yml.tftpl"
    } }
    "102-traefik" = { prefix = "traefik", files = {
      mcphub      = "mcphub.yml.tftpl"
      n8n         = "n8n.yml.tftpl"
      nas         = "nas.yml.tftpl"
      registry    = "registry.yml.tftpl"
      filebeat    = "filebeat.yml.tftpl"
      cloudflared = "cloudflared-docker-compose.yml.tftpl"
      middlewares = "middlewares.yml.tftpl"
    } }
    "103-coredns" = { prefix = "coredns", files = {
      corefile       = "Corefile.tftpl"
      docker_compose = "docker-compose.yml.tftpl"
      filebeat       = "filebeat.yml.tftpl"
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
    "110-n8n" = { prefix = "n8n", files = {
      filebeat       = "filebeat.yml.tftpl"
      docker_compose = "docker-compose.yml.tftpl"
      env            = "n8n.env.tftpl"
    } }
    "112-mcphub" = { prefix = "mcphub", files = {
      filebeat           = "filebeat.yml.tftpl"
      docker_compose     = "docker-compose.yml.tftpl"
      mcp_settings       = "mcp_settings.json.tftpl"
      env                = ".env.tftpl"
      op_connect_compose = "docker-compose-op-connect.yml.tftpl"
    } }
    "220-youtube" = { prefix = "youtube", files = {
      filebeat       = "filebeat.yml.tftpl"
      docker_compose = "docker-compose.yml.tftpl"
      env            = ".env.tftpl"
    } }
  }

  service_templates = merge([
    for svc_dir, svc in local._svc_tpl : {
      for name, file in svc.files :
      "${svc.prefix}_${name}" => {
        source = "${path.module}/../../${svc_dir}/templates/${file}"
        output = "${svc.prefix}/${trimsuffix(file, ".tftpl")}"
      }
    }
  ]...)

  # Root-level templates that output to the top-level (not in service subdirs).
  root_templates = {
    traefik_elk = {
      source = "${path.module}/../../102-traefik/templates/traefik-elk.yml.tftpl"
      output = "traefik-elk.yml"
    }
  }
}
