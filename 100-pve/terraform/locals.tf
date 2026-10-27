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
  container_sizing = {
    elk      = { memory = 10240, swap = 4096, cores = 4, cpu_limit = 2, cpu_units = 512, disk_size = 64, description = "ELK Stack (Elasticsearch, Logstash, Kibana)", startup = { order = 2, up_delay = 60, down_delay = 120 }, mount_points = [{ volume = "/mnt/nas-elk", path = "/mnt/nas-elk", replicate = false }] }
    cliproxy = { memory = 4096, swap = 2048, cores = 4, cpu_limit = 1.5, cpu_units = 1024, disk_size = 100, description = "Cloudflare Tunnel and GitHub Actions Runner", startup = { order = 1, up_delay = 30, down_delay = 60 }, mount_points = [{ volume = "/mnt/pve/shared/ci-cache", path = "/mnt/nas-cache", backup = false, replicate = false }] }
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
    jclee-prd = "local:snippets/youtube-user-data.yaml"
  }
  vm_definitions = {
    jclee-prd = {
      vmid                  = 220
      hostname              = "jclee-prd"
      description           = "Production Media Server"
      memory                = 24576
      balloon_min           = 20480
      on_boot               = true
      startup               = { order = 3, up_delay = 60, down_delay = 120 }
      cores                 = 6
      cpu_limit             = 4
      cpu_numa              = true
      cpu_units             = 1024
      disk_size             = 400
      disk_backup           = true
      disk_cache            = "none"
      disk_replicate        = true
      efi_pre_enrolled_keys = false
      bios                  = "ovmf"
      hotplug               = "memory,usb"
      machine               = "q35"
      hostpci_devices = [
        { device = "hostpci0", mapping = "gpu", pcie = false, rombar = true, xvga = true }
      ]
      serial_devices = [{ device = "socket" }]
      tablet_device  = false
      vga_type       = "serial0"
      usb_devices = [
        { host = "04e8:6860" },
        { host = "04e8:6860", usb3 = true },
      ]
    }
    jclee-dev = {
      vmid          = 200
      description   = "OpenCode Development VM"
      memory        = 28672
      balloon_min   = 16384
      on_boot       = true
      startup       = { order = 4, up_delay = 0, down_delay = 30 }
      cores         = 8
      cpu_limit     = 6
      cpu_numa      = true
      cpu_units     = 512
      disk_size     = 500
      hotplug       = "0"
      hostname      = "jclee-dev"
      bios          = "seabios"
      tpm_enabled   = true
      machine       = "q35"
      tablet_device = false

      serial_devices = [{ device = "socket" }]
      vga_type       = "serial0"
    }
  }

  proxmox_operating_budget_mb = 60 * 1024
  proxmox_reserved_memory_mb  = 8 * 1024
  startup_guest_budget_mb     = local.proxmox_operating_budget_mb - local.proxmox_reserved_memory_mb
  startup_guest_minimum_memory_mb = sum([
    for container in values(local.container_sizing) : container.memory
    if try(container.start_on_boot, true)
    ]) + sum([
    for vm in values(local.vm_definitions) : vm.balloon_min
    if try(vm.on_boot, true)
  ])
  total_guest_cpu_limit = sum(concat(
    [for container in values(local.container_sizing) : coalesce(try(container.cpu_limit, null), container.cores)],
    [for vm in values(local.vm_definitions) : coalesce(try(vm.cpu_limit, null), vm.cores)],
  ))
  total_guest_disk_gb             = sum([for container in values(local.container_sizing) : container.disk_size]) + sum([for vm in values(local.vm_definitions) : vm.disk_size])
  proxmox_cpu_limit_budget        = 14
  proxmox_ssd_capacity_gb         = 882
  proxmox_ssd_overcommit_ratio    = 1.25
  proxmox_ssd_allocation_limit_gb = local.proxmox_ssd_capacity_gb * local.proxmox_ssd_overcommit_ratio
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
