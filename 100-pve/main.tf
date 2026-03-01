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
  source = "./envs/prod"
}

# env-config module removed — non-hosts template vars inlined below
# All IP/port refs now use hosts.X.Y directly in templates

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
  hostpci_devices  = try(each.value.hostpci_devices, [])

  cloud_init_file_id = try(local.cloud_init_files[each.key], null)
}

moved {
  from = proxmox_virtual_environment_vm.mcphub
  to   = module.vm["mcphub"].proxmox_virtual_environment_vm.this
}
