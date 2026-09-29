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
  effective_homelab_tunnel_token = trimspace(var.homelab_tunnel_token)

  infrastructure_nodes = [
    for name, host in module.hosts.hosts : {
      name = name
      ip   = host.ip
      vmid = host.vmid
    }
    if !contains(host.roles, "hypervisor") && !contains(host.roles, "workstation") && !contains(host.roles, "nas")
  ]

  # Container sizing (IP/VMID from module.hosts, sizing here)
  # Memory budget: Optimized with per-container swap for efficient memory utilization
  # Strategy: Match live Proxmox allocation for active containers.
  container_sizing = {
    elk      = { memory = 10240, swap = 5120, cores = 4, cpu_limit = 2, cpu_units = 512, disk_size = 64, description = "ELK Stack (Elasticsearch, Logstash, Kibana)", mount_points = [{ volume = "/mnt/nas-elk", path = "/mnt/nas-elk", replicate = false }] }
    cliproxy = { memory = 8192, swap = 1024, cores = 2, cpu_limit = 1.5, cpu_units = 512, disk_size = 100, description = "Squid Forward Proxy", mount_points = [{ volume = "/mnt/pve/shared/ci-cache", path = "/mnt/nas-cache", backup = false, replicate = false }] }
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

  lxc_cpu_limits = {
    for name, container in local.containers : name => container
    if lookup(container, "cpu_limit", null) != null
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
    youtube = "local:snippets/youtube-user-data.yaml"
  }
  vm_definitions = {
    youtube = {
      vmid                  = 220
      description           = "YouTube Media Server"
      memory                = 32768
      balloon_min           = 16384
      cores                 = 8
      cpu_limit             = 4
      cpu_numa              = true
      cpu_units             = 512
      disk_size             = 400
      disk_backup           = true
      disk_cache            = "none"
      disk_replicate        = true
      efi_pre_enrolled_keys = false
      bios                  = "ovmf"
      hotplug               = "memory,usb"
      machine               = "q35"
      hostpci_devices = [
        { device = "hostpci0", mapping = "gpu", pcie = true, xvga = true }
      ]
      serial_devices = [{ device = "socket" }]
      tablet_device  = false
      usb_devices = [
        { host = "04e8:6860" },
        { host = "04e8:6860", usb3 = true },
      ]
    }
    jclee-dev = {
      vmid          = 200
      description   = "OpenCode Development VM (oc)"
      memory        = 28672
      balloon_min   = 20480
      cores         = 8
      cpu_limit     = 4
      cpu_numa      = true
      cpu_units     = 768
      disk_size     = 200
      hotplug       = "0"
      hostname      = "oc"
      bios          = "seabios"
      machine       = "q35"
      tablet_device = false
      vga_clipboard = "vnc"
      vga_type      = "virtio"
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
    "proxmox_ssh_private_key",
    "telegram_bot_token",
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
    "105-elk" = { prefix = "elk", files = {
      filebeat            = "filebeat.yml.tftpl"
      docker_compose      = "docker-compose.yml.tftpl"
      logstash_conf       = "logstash.conf.tftpl"
      logstash_yml        = "logstash.yml.tftpl"
      ilm_policy          = "ilm-policy.json.tftpl"
      setup_ilm           = "setup-ilm.sh.tftpl"
      dockerfile_logstash = "Dockerfile.logstash.tftpl"
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

}
