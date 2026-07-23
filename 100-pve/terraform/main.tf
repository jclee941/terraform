provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = local.effective_proxmox_api_token
  insecure  = var.proxmox_insecure
}

provider "onepassword" {}

# =============================================================================
# HOST INVENTORY (Single Source of Truth)
# =============================================================================

module "hosts" {
  source = "../envs/prod"
}

# env-config module removed — non-hosts template vars inlined below
# All IP/port refs now use hosts.X.Y directly in templates

# =============================================================================
# CONTAINER MODULES
# =============================================================================

module "lxc" {
  source   = "../../modules/proxmox/lxc"
  for_each = local.containers

  node_name        = local.node_name
  vmid             = each.value.vmid
  hostname         = each.value.hostname
  ip_address       = each.value.ip
  memory           = each.value.memory
  swap             = each.value.swap
  cores            = each.value.cores
  cpu_units        = lookup(each.value, "cpu_units", null)
  disk_size        = each.value.disk_size
  description      = each.value.description
  privileged       = lookup(each.value, "privileged", false)
  protection       = lookup(each.value, "protection", false)
  start_on_boot    = lookup(each.value, "start_on_boot", true)
  network_gateway  = var.network_gateway
  dns_servers      = var.dns_servers
  datastore_id     = var.datastore_id
  managed_vmid_min = var.managed_vmid_range.min
  managed_vmid_max = var.managed_vmid_range.max
  ssh_public_keys  = var.ssh_public_keys
  mount_points     = lookup(each.value, "mount_points", [])
}

# =============================================================================
# VIRTUAL MACHINES (VMs)
# =============================================================================

module "vm" {
  source   = "../../modules/proxmox/vm"
  for_each = local.vm_definitions

  node_name             = local.node_name
  vmid                  = each.value.vmid
  hostname              = try(each.value.hostname, each.key)
  description           = each.value.description
  ip_address            = module.hosts.hosts[each.key].ip
  memory                = each.value.memory
  cores                 = each.value.cores
  cpu_limit             = try(each.value.cpu_limit, null)
  cpu_numa              = try(each.value.cpu_numa, false)
  cpu_units             = try(each.value.cpu_units, null)
  disk_size             = each.value.disk_size
  disk_backup           = try(each.value.disk_backup, null)
  disk_cache            = try(each.value.disk_cache, null)
  disk_replicate        = try(each.value.disk_replicate, null)
  bios                  = try(each.value.bios, "seabios")
  efi_pre_enrolled_keys = try(each.value.efi_pre_enrolled_keys, false)
  hotplug               = try(each.value.hotplug, null)
  keyboard_layout       = try(each.value.keyboard_layout, null)
  machine               = try(each.value.machine, "pc")
  network_gateway       = var.network_gateway
  dns_servers           = var.dns_servers
  datastore_id          = var.datastore_id
  managed_vmid_min      = var.managed_vmid_range.min
  managed_vmid_max      = var.managed_vmid_range.max
  hostpci_devices       = try(each.value.hostpci_devices, [])
  protection            = try(each.value.protection, true)
  scsi_hardware         = try(each.value.scsi_hardware, "virtio-scsi-single")
  serial_devices        = try(each.value.serial_devices, [])
  tablet_device         = try(each.value.tablet_device, false)
  vga_clipboard         = try(each.value.vga_clipboard, null)
  vga_memory            = try(each.value.vga_memory, 16)
  vga_type              = try(each.value.vga_type, "std")
  balloon_min           = try(each.value.balloon_min, 0)

  cloud_init_file_id = try(local.cloud_init_files[each.key], null)
}
