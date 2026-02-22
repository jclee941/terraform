# LXC & VM Module Tests
# Modules: modules/proxmox/lxc, modules/proxmox/vm (require bpg/proxmox provider)
# Tests validate input validation rules and preconditions using mock provider.
# Full resource creation requires a live Proxmox connection.
# NOTE: Single mock_provider per file required (TF <1.10 limitation).

mock_provider "proxmox" {
  override_data {
    target = data.proxmox_virtual_environment_nodes.nodes
    values = {
      names = ["pve"]
    }
  }

  override_resource {
    target = proxmox_virtual_environment_vm.this
    values = {
      id        = "112"
      vm_id     = 112
      name      = "mock-vm"
      node_name = "pve"
      started   = true
    }
  }
}

# --- Positive tests ---

# Valid VMID within managed range passes all preconditions
run "test_valid_vmid_in_range" {
  command = plan

  module {
    source = "../../../modules/proxmox/lxc"
  }

  variables {
    node_name        = "pve"
    vmid             = 105
    hostname         = "test-elk"
    ip_address       = "192.168.50.105"
    memory           = 8192
    cores            = 4
    disk_size        = 64
    description      = "ELK Stack test"
    network_gateway  = "192.168.50.1"
    dns_servers      = ["192.168.50.1"]
    managed_vmid_min = 100
    managed_vmid_max = 255
    swap             = 0
    datastore_id     = "local-lvm"
    template_file_id = "local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst"
  }

  assert {
    condition     = output.vmid == 105
    error_message = "VMID must be passed through to output"
  }
}

# IP address is passed through unchanged
run "test_ip_address_passthrough" {
  command = plan

  module {
    source = "../../../modules/proxmox/lxc"
  }

  variables {
    node_name        = "pve"
    vmid             = 102
    hostname         = "test-traefik"
    ip_address       = "192.168.50.102"
    memory           = 512
    cores            = 2
    disk_size        = 8
    description      = "Traefik test"
    network_gateway  = "192.168.50.1"
    dns_servers      = ["192.168.50.1"]
    managed_vmid_min = 100
    managed_vmid_max = 255
    swap             = 0
    datastore_id     = "local-lvm"
    template_file_id = "local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst"
  }

  assert {
    condition     = output.ip_address == "192.168.50.102"
    error_message = "IP address must be passed through to output"
  }
}

# --- Precondition failure tests ---

# VMID below managed range triggers precondition failure
run "test_vmid_below_range" {
  command = plan

  module {
    source = "../../../modules/proxmox/lxc"
  }

  variables {
    node_name        = "pve"
    vmid             = 50
    hostname         = "test-invalid"
    ip_address       = "192.168.50.50"
    memory           = 512
    cores            = 1
    disk_size        = 8
    description      = "Invalid VMID test"
    network_gateway  = "192.168.50.1"
    dns_servers      = ["192.168.50.1"]
    managed_vmid_min = 100
    managed_vmid_max = 255
    swap             = 0
    datastore_id     = "local-lvm"
    template_file_id = "local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst"
  }

  expect_failures = [
    var.vmid,
  ]
}

# VMID above managed range — within validation (100-999) but outside managed range
run "test_vmid_above_managed_range" {
  command = plan

  module {
    source = "../../../modules/proxmox/lxc"
  }

  variables {
    node_name        = "pve"
    vmid             = 999
    hostname         = "test-invalid-high"
    ip_address       = "192.168.50.200"
    memory           = 512
    cores            = 1
    disk_size        = 8
    description      = "Invalid VMID test (too high)"
    network_gateway  = "192.168.50.1"
    dns_servers      = ["192.168.50.1"]
    managed_vmid_min = 100
    managed_vmid_max = 255
    swap             = 0
    datastore_id     = "local-lvm"
    template_file_id = "local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst"
  }

  expect_failures = [
    proxmox_virtual_environment_container.this,
  ]
}

# Memory below 128 MB triggers variable validation failure
run "test_memory_too_low" {
  command = plan

  module {
    source = "../../../modules/proxmox/lxc"
  }

  variables {
    node_name        = "pve"
    vmid             = 101
    hostname         = "test-low-mem"
    ip_address       = "192.168.50.101"
    memory           = 64
    cores            = 1
    disk_size        = 8
    description      = "Low memory test"
    network_gateway  = "192.168.50.1"
    dns_servers      = ["192.168.50.1"]
    managed_vmid_min = 100
    managed_vmid_max = 255
    swap             = 0
    datastore_id     = "local-lvm"
    template_file_id = "local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst"
  }

  expect_failures = [
    var.memory,
  ]
}

# =============================================================================
# VM Module Tests (modules/proxmox/vm)
# =============================================================================

run "test_vm_valid" {
  command = plan

  module {
    source = "../../../modules/proxmox/vm"
  }

  variables {
    node_name         = "pve"
    vmid              = 112
    hostname          = "mcphub"
    ip_address        = "192.168.50.112"
    memory            = 6144
    cores             = 2
    disk_size         = 32
    description       = "MCP Hub VM"
    network_gateway   = "192.168.50.1"
    dns_servers       = ["192.168.50.1"]
    managed_vmid_min  = 100
    managed_vmid_max  = 255
    datastore_id      = "local-lvm"
    clone_template_id = 9000
  }

  assert {
    condition     = output.vmid == 112
    error_message = "VMID must be passed through to output"
  }
}

run "test_vm_ip_passthrough" {
  command = plan

  module {
    source = "../../../modules/proxmox/vm"
  }

  variables {
    node_name         = "pve"
    vmid              = 101
    hostname          = "runner"
    ip_address        = "192.168.50.101"
    memory            = 16384
    cores             = 8
    disk_size         = 64
    description       = "Runner VM"
    network_gateway   = "192.168.50.1"
    dns_servers       = ["192.168.50.1"]
    managed_vmid_min  = 100
    managed_vmid_max  = 255
    datastore_id      = "local-lvm"
    clone_template_id = 9000
  }

  assert {
    condition     = output.ip_address == "192.168.50.101"
    error_message = "IP address must be passed through to output"
  }
}

run "test_vm_vmid_below_range" {
  command = plan

  module {
    source = "../../../modules/proxmox/vm"
  }

  variables {
    node_name         = "pve"
    vmid              = 50
    hostname          = "test-invalid"
    ip_address        = "192.168.50.50"
    memory            = 1024
    cores             = 1
    disk_size         = 16
    description       = "Invalid VMID test"
    network_gateway   = "192.168.50.1"
    dns_servers       = ["192.168.50.1"]
    managed_vmid_min  = 100
    managed_vmid_max  = 255
    datastore_id      = "local-lvm"
    clone_template_id = 9000
  }

  expect_failures = [
    var.vmid,
  ]
}

run "test_vm_vmid_above_range" {
  command = plan

  module {
    source = "../../../modules/proxmox/vm"
  }

  variables {
    node_name         = "pve"
    vmid              = 1000
    hostname          = "test-invalid-high"
    ip_address        = "192.168.50.200"
    memory            = 1024
    cores             = 1
    disk_size         = 16
    description       = "Invalid VMID test (too high)"
    network_gateway   = "192.168.50.1"
    dns_servers       = ["192.168.50.1"]
    managed_vmid_min  = 100
    managed_vmid_max  = 255
    datastore_id      = "local-lvm"
    clone_template_id = 9000
  }

  expect_failures = [
    var.vmid,
  ]
}

run "test_vm_memory_too_low" {
  command = plan

  module {
    source = "../../../modules/proxmox/vm"
  }

  variables {
    node_name         = "pve"
    vmid              = 112
    hostname          = "test-low-mem"
    ip_address        = "192.168.50.112"
    memory            = 128
    cores             = 1
    disk_size         = 16
    description       = "Low memory test"
    network_gateway   = "192.168.50.1"
    dns_servers       = ["192.168.50.1"]
    managed_vmid_min  = 100
    managed_vmid_max  = 255
    datastore_id      = "local-lvm"
    clone_template_id = 9000
  }

  expect_failures = [
    var.memory,
  ]
}

run "test_vm_memory_not_aligned" {
  command = plan

  module {
    source = "../../../modules/proxmox/vm"
  }

  variables {
    node_name         = "pve"
    vmid              = 112
    hostname          = "test-bad-mem"
    ip_address        = "192.168.50.112"
    memory            = 1000
    cores             = 1
    disk_size         = 16
    description       = "Unaligned memory test"
    network_gateway   = "192.168.50.1"
    dns_servers       = ["192.168.50.1"]
    managed_vmid_min  = 100
    managed_vmid_max  = 255
    datastore_id      = "local-lvm"
    clone_template_id = 9000
  }

  expect_failures = [
    proxmox_virtual_environment_vm.this,
  ]
}

run "test_vm_invalid_hostname" {
  command = plan

  module {
    source = "../../../modules/proxmox/vm"
  }

  variables {
    node_name         = "pve"
    vmid              = 112
    hostname          = "INVALID_HOST"
    ip_address        = "192.168.50.112"
    memory            = 2048
    cores             = 1
    disk_size         = 16
    description       = "Invalid hostname test"
    network_gateway   = "192.168.50.1"
    dns_servers       = ["192.168.50.1"]
    managed_vmid_min  = 100
    managed_vmid_max  = 255
    datastore_id      = "local-lvm"
    clone_template_id = 9000
  }

  expect_failures = [
    var.hostname,
  ]
}

run "test_vm_invalid_bios" {
  command = plan

  module {
    source = "../../../modules/proxmox/vm"
  }

  variables {
    node_name         = "pve"
    vmid              = 112
    hostname          = "test-bios"
    ip_address        = "192.168.50.112"
    memory            = 2048
    cores             = 1
    disk_size         = 16
    description       = "Invalid BIOS test"
    network_gateway   = "192.168.50.1"
    dns_servers       = ["192.168.50.1"]
    managed_vmid_min  = 100
    managed_vmid_max  = 255
    datastore_id      = "local-lvm"
    clone_template_id = 9000
    bios              = "uefi"
  }

  expect_failures = [
    var.bios,
  ]
}

run "test_vm_invalid_disk_interface" {
  command = plan

  module {
    source = "../../../modules/proxmox/vm"
  }

  variables {
    node_name         = "pve"
    vmid              = 112
    hostname          = "test-disk"
    ip_address        = "192.168.50.112"
    memory            = 2048
    cores             = 1
    disk_size         = 16
    description       = "Invalid disk interface test"
    network_gateway   = "192.168.50.1"
    dns_servers       = ["192.168.50.1"]
    managed_vmid_min  = 100
    managed_vmid_max  = 255
    datastore_id      = "local-lvm"
    clone_template_id = 9000
    disk_interface    = "nvme0"
  }

  expect_failures = [
    var.disk_interface,
  ]
}

run "test_vm_disk_too_small" {
  command = plan

  module {
    source = "../../../modules/proxmox/vm"
  }

  variables {
    node_name         = "pve"
    vmid              = 112
    hostname          = "test-small-disk"
    ip_address        = "192.168.50.112"
    memory            = 2048
    cores             = 1
    disk_size         = 2
    description       = "Small disk test"
    network_gateway   = "192.168.50.1"
    dns_servers       = ["192.168.50.1"]
    managed_vmid_min  = 100
    managed_vmid_max  = 255
    datastore_id      = "local-lvm"
    clone_template_id = 9000
  }

  expect_failures = [
    var.disk_size,
  ]
}

run "test_vm_invalid_node_name" {
  command = plan

  module {
    source = "../../../modules/proxmox/vm"
  }

  variables {
    node_name         = "nonexistent"
    vmid              = 112
    hostname          = "test-node"
    ip_address        = "192.168.50.112"
    memory            = 2048
    cores             = 1
    disk_size         = 16
    description       = "Invalid node test"
    network_gateway   = "192.168.50.1"
    dns_servers       = ["192.168.50.1"]
    managed_vmid_min  = 100
    managed_vmid_max  = 255
    datastore_id      = "local-lvm"
    clone_template_id = 9000
  }

  expect_failures = [
    proxmox_virtual_environment_vm.this,
  ]
}
