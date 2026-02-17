# VM Module Tests
# Module: modules/proxmox/vm (requires bpg/proxmox provider)
# Tests validate input validation rules and lifecycle preconditions using mock provider.
# Full resource creation requires a live Proxmox connection.
# Run: terraform test (from tests/modules/proxmox/)

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
      id        = "999"
      vm_id     = 999
      name      = "test-vm"
      node_name = "pve"
      started   = true
    }
  }
}

# =============================================================================
# Positive Tests — valid configurations that must plan successfully
# =============================================================================

# Valid VM with all required variables and realistic homelab values
run "test_valid_vm_creation" {
  command = plan

  module {
    source = "../../../modules/proxmox/vm"
  }

  variables {
    node_name         = "pve"
    vmid              = 999
    hostname          = "test-vm"
    ip_address        = "192.168.50.199"
    memory            = 2048
    cores             = 2
    disk_size         = 16
    description       = "Test VM for module validation"
    network_gateway   = "192.168.50.1"
    dns_servers       = ["192.168.50.1"]
    managed_vmid_min  = 100
    managed_vmid_max  = 999
    datastore_id      = "local-lvm"
    clone_template_id = 9000
  }

  assert {
    condition     = output.vmid == 999
    error_message = "VMID must be passed through to output unchanged"
  }

  assert {
    condition     = output.ip_address == "192.168.50.199"
    error_message = "IP address must be passed through to output unchanged"
  }
}

# IP address output passthrough — verifies output.ip_address reflects var.ip_address
run "test_ip_address_passthrough" {
  command = plan

  module {
    source = "../../../modules/proxmox/vm"
  }

  variables {
    node_name         = "pve"
    vmid              = 200
    hostname          = "oc"
    ip_address        = "192.168.50.200"
    memory            = 16384
    cores             = 8
    disk_size         = 64
    description       = "Dev GPU VM"
    network_gateway   = "192.168.50.1"
    dns_servers       = ["192.168.50.1"]
    managed_vmid_min  = 100
    managed_vmid_max  = 255
    datastore_id      = "local-lvm"
    clone_template_id = 9000
  }

  assert {
    condition     = output.ip_address == "192.168.50.200"
    error_message = "IP address must be passed through to output"
  }
}

# Output shape — status map must contain 'started' and 'node' keys
run "test_output_status_shape" {
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

  assert {
    condition     = can(output.status.started)
    error_message = "output.status must contain 'started' key"
  }

  assert {
    condition     = can(output.status.node)
    error_message = "output.status must contain 'node' key"
  }
}

# Optional BIOS override — ovmf is a valid value
run "test_valid_bios_ovmf" {
  command = plan

  module {
    source = "../../../modules/proxmox/vm"
  }

  variables {
    node_name         = "pve"
    vmid              = 220
    hostname          = "staging"
    ip_address        = "192.168.50.220"
    memory            = 4096
    cores             = 4
    disk_size         = 32
    description       = "Staging VM with UEFI BIOS"
    network_gateway   = "192.168.50.1"
    dns_servers       = ["192.168.50.1"]
    managed_vmid_min  = 100
    managed_vmid_max  = 255
    datastore_id      = "local-lvm"
    clone_template_id = 9000
    bios              = "ovmf"
  }

  assert {
    condition     = output.vmid == 220
    error_message = "VMID must be passed through to output"
  }
}

# Optional machine type override — q35 is a valid value
run "test_valid_machine_q35" {
  command = plan

  module {
    source = "../../../modules/proxmox/vm"
  }

  variables {
    node_name         = "pve"
    vmid              = 200
    hostname          = "oc"
    ip_address        = "192.168.50.200"
    memory            = 8192
    cores             = 4
    disk_size         = 64
    description       = "Dev VM with q35 machine type"
    network_gateway   = "192.168.50.1"
    dns_servers       = ["192.168.50.1"]
    managed_vmid_min  = 100
    managed_vmid_max  = 255
    datastore_id      = "local-lvm"
    clone_template_id = 9000
    machine           = "q35"
  }

  assert {
    condition     = output.vmid == 200
    error_message = "VMID must be passed through to output"
  }
}

# Valid virtio disk interface
run "test_valid_disk_interface_virtio" {
  command = plan

  module {
    source = "../../../modules/proxmox/vm"
  }

  variables {
    node_name         = "pve"
    vmid              = 999
    hostname          = "test-vm"
    ip_address        = "192.168.50.199"
    memory            = 2048
    cores             = 2
    disk_size         = 16
    description       = "Test VM with virtio disk"
    network_gateway   = "192.168.50.1"
    dns_servers       = ["192.168.50.1"]
    managed_vmid_min  = 100
    managed_vmid_max  = 999
    datastore_id      = "local-lvm"
    clone_template_id = 9000
    disk_interface    = "virtio0"
  }

  assert {
    condition     = output.vmid == 999
    error_message = "VMID must be passed through to output"
  }
}

# =============================================================================
# Negative Tests — invalid inputs that must trigger validation failures
# =============================================================================

# VMID below the allowed range (100-999) triggers var.vmid validation
run "test_vmid_below_range" {
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
    description       = "Invalid VMID below range"
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

# VMID above the allowed range (100-999) triggers var.vmid validation
run "test_vmid_above_range" {
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
    description       = "Invalid VMID above range"
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

# VMID within var validation (100-999) but outside managed range triggers precondition
run "test_vmid_outside_managed_range" {
  command = plan

  module {
    source = "../../../modules/proxmox/vm"
  }

  variables {
    node_name         = "pve"
    vmid              = 999
    hostname          = "test-out-of-managed"
    ip_address        = "192.168.50.200"
    memory            = 1024
    cores             = 1
    disk_size         = 16
    description       = "VMID outside managed range precondition test"
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

# Hostname with uppercase letters violates DNS label validation
run "test_invalid_hostname_uppercase" {
  command = plan

  module {
    source = "../../../modules/proxmox/vm"
  }

  variables {
    node_name         = "pve"
    vmid              = 999
    hostname          = "INVALID-HOST"
    ip_address        = "192.168.50.199"
    memory            = 2048
    cores             = 1
    disk_size         = 16
    description       = "Invalid hostname uppercase test"
    network_gateway   = "192.168.50.1"
    dns_servers       = ["192.168.50.1"]
    managed_vmid_min  = 100
    managed_vmid_max  = 999
    datastore_id      = "local-lvm"
    clone_template_id = 9000
  }

  expect_failures = [
    var.hostname,
  ]
}

# Hostname starting with a digit violates DNS label validation
run "test_invalid_hostname_starts_with_digit" {
  command = plan

  module {
    source = "../../../modules/proxmox/vm"
  }

  variables {
    node_name         = "pve"
    vmid              = 999
    hostname          = "1invalid"
    ip_address        = "192.168.50.199"
    memory            = 2048
    cores             = 1
    disk_size         = 16
    description       = "Invalid hostname starts with digit"
    network_gateway   = "192.168.50.1"
    dns_servers       = ["192.168.50.1"]
    managed_vmid_min  = 100
    managed_vmid_max  = 999
    datastore_id      = "local-lvm"
    clone_template_id = 9000
  }

  expect_failures = [
    var.hostname,
  ]
}

# Hostname with underscore violates DNS label validation
run "test_invalid_hostname_underscore" {
  command = plan

  module {
    source = "../../../modules/proxmox/vm"
  }

  variables {
    node_name         = "pve"
    vmid              = 999
    hostname          = "test_vm"
    ip_address        = "192.168.50.199"
    memory            = 2048
    cores             = 1
    disk_size         = 16
    description       = "Invalid hostname with underscore"
    network_gateway   = "192.168.50.1"
    dns_servers       = ["192.168.50.1"]
    managed_vmid_min  = 100
    managed_vmid_max  = 999
    datastore_id      = "local-lvm"
    clone_template_id = 9000
  }

  expect_failures = [
    var.hostname,
  ]
}

# IP address with CIDR notation violates ip_address validation
run "test_invalid_ip_with_cidr" {
  command = plan

  module {
    source = "../../../modules/proxmox/vm"
  }

  variables {
    node_name         = "pve"
    vmid              = 999
    hostname          = "test-vm"
    ip_address        = "192.168.50.199/24"
    memory            = 2048
    cores             = 1
    disk_size         = 16
    description       = "Invalid IP with CIDR notation"
    network_gateway   = "192.168.50.1"
    dns_servers       = ["192.168.50.1"]
    managed_vmid_min  = 100
    managed_vmid_max  = 999
    datastore_id      = "local-lvm"
    clone_template_id = 9000
  }

  expect_failures = [
    var.ip_address,
  ]
}

# IP address as hostname string violates ip_address validation
run "test_invalid_ip_as_hostname" {
  command = plan

  module {
    source = "../../../modules/proxmox/vm"
  }

  variables {
    node_name         = "pve"
    vmid              = 999
    hostname          = "test-vm"
    ip_address        = "not-an-ip"
    memory            = 2048
    cores             = 1
    disk_size         = 16
    description       = "Invalid IP as hostname string"
    network_gateway   = "192.168.50.1"
    dns_servers       = ["192.168.50.1"]
    managed_vmid_min  = 100
    managed_vmid_max  = 999
    datastore_id      = "local-lvm"
    clone_template_id = 9000
  }

  expect_failures = [
    var.ip_address,
  ]
}

# Memory below 512 MB minimum triggers var.memory validation
run "test_memory_too_low" {
  command = plan

  module {
    source = "../../../modules/proxmox/vm"
  }

  variables {
    node_name         = "pve"
    vmid              = 999
    hostname          = "test-low-mem"
    ip_address        = "192.168.50.199"
    memory            = 256
    cores             = 1
    disk_size         = 16
    description       = "Memory below 512 MB minimum"
    network_gateway   = "192.168.50.1"
    dns_servers       = ["192.168.50.1"]
    managed_vmid_min  = 100
    managed_vmid_max  = 999
    datastore_id      = "local-lvm"
    clone_template_id = 9000
  }

  expect_failures = [
    var.memory,
  ]
}

# Memory above 65536 MB maximum triggers var.memory validation
run "test_memory_too_high" {
  command = plan

  module {
    source = "../../../modules/proxmox/vm"
  }

  variables {
    node_name         = "pve"
    vmid              = 999
    hostname          = "test-high-mem"
    ip_address        = "192.168.50.199"
    memory            = 131072
    cores             = 1
    disk_size         = 16
    description       = "Memory above 65536 MB maximum"
    network_gateway   = "192.168.50.1"
    dns_servers       = ["192.168.50.1"]
    managed_vmid_min  = 100
    managed_vmid_max  = 999
    datastore_id      = "local-lvm"
    clone_template_id = 9000
  }

  expect_failures = [
    var.memory,
  ]
}

# Memory not divisible by 256 triggers lifecycle precondition (not var validation)
run "test_memory_not_aligned" {
  command = plan

  module {
    source = "../../../modules/proxmox/vm"
  }

  variables {
    node_name         = "pve"
    vmid              = 999
    hostname          = "test-bad-mem"
    ip_address        = "192.168.50.199"
    memory            = 1000
    cores             = 1
    disk_size         = 16
    description       = "Memory not divisible by 256"
    network_gateway   = "192.168.50.1"
    dns_servers       = ["192.168.50.1"]
    managed_vmid_min  = 100
    managed_vmid_max  = 999
    datastore_id      = "local-lvm"
    clone_template_id = 9000
  }

  expect_failures = [
    proxmox_virtual_environment_vm.this,
  ]
}

# CPU cores above 16 maximum triggers var.cores validation
run "test_cores_too_high" {
  command = plan

  module {
    source = "../../../modules/proxmox/vm"
  }

  variables {
    node_name         = "pve"
    vmid              = 999
    hostname          = "test-many-cores"
    ip_address        = "192.168.50.199"
    memory            = 2048
    cores             = 32
    disk_size         = 16
    description       = "CPU cores above 16 maximum"
    network_gateway   = "192.168.50.1"
    dns_servers       = ["192.168.50.1"]
    managed_vmid_min  = 100
    managed_vmid_max  = 999
    datastore_id      = "local-lvm"
    clone_template_id = 9000
  }

  expect_failures = [
    var.cores,
  ]
}

# Disk size below 8 GB minimum triggers var.disk_size validation
run "test_disk_too_small" {
  command = plan

  module {
    source = "../../../modules/proxmox/vm"
  }

  variables {
    node_name         = "pve"
    vmid              = 999
    hostname          = "test-small-disk"
    ip_address        = "192.168.50.199"
    memory            = 2048
    cores             = 1
    disk_size         = 4
    description       = "Disk size below 8 GB minimum"
    network_gateway   = "192.168.50.1"
    dns_servers       = ["192.168.50.1"]
    managed_vmid_min  = 100
    managed_vmid_max  = 999
    datastore_id      = "local-lvm"
    clone_template_id = 9000
  }

  expect_failures = [
    var.disk_size,
  ]
}

# Disk size above 500 GB maximum triggers var.disk_size validation
run "test_disk_too_large" {
  command = plan

  module {
    source = "../../../modules/proxmox/vm"
  }

  variables {
    node_name         = "pve"
    vmid              = 999
    hostname          = "test-large-disk"
    ip_address        = "192.168.50.199"
    memory            = 2048
    cores             = 1
    disk_size         = 1000
    description       = "Disk size above 500 GB maximum"
    network_gateway   = "192.168.50.1"
    dns_servers       = ["192.168.50.1"]
    managed_vmid_min  = 100
    managed_vmid_max  = 999
    datastore_id      = "local-lvm"
    clone_template_id = 9000
  }

  expect_failures = [
    var.disk_size,
  ]
}

# Invalid BIOS value (not seabios or ovmf) triggers var.bios validation
run "test_invalid_bios" {
  command = plan

  module {
    source = "../../../modules/proxmox/vm"
  }

  variables {
    node_name         = "pve"
    vmid              = 999
    hostname          = "test-bios"
    ip_address        = "192.168.50.199"
    memory            = 2048
    cores             = 1
    disk_size         = 16
    description       = "Invalid BIOS type test"
    network_gateway   = "192.168.50.1"
    dns_servers       = ["192.168.50.1"]
    managed_vmid_min  = 100
    managed_vmid_max  = 999
    datastore_id      = "local-lvm"
    clone_template_id = 9000
    bios              = "uefi"
  }

  expect_failures = [
    var.bios,
  ]
}

# Invalid machine type (not pc or q35) triggers var.machine validation
run "test_invalid_machine_type" {
  command = plan

  module {
    source = "../../../modules/proxmox/vm"
  }

  variables {
    node_name         = "pve"
    vmid              = 999
    hostname          = "test-machine"
    ip_address        = "192.168.50.199"
    memory            = 2048
    cores             = 1
    disk_size         = 16
    description       = "Invalid machine type test"
    network_gateway   = "192.168.50.1"
    dns_servers       = ["192.168.50.1"]
    managed_vmid_min  = 100
    managed_vmid_max  = 999
    datastore_id      = "local-lvm"
    clone_template_id = 9000
    machine           = "i440fx"
  }

  expect_failures = [
    var.machine,
  ]
}

# Invalid disk interface (nvme0 not matching pattern) triggers var.disk_interface validation
run "test_invalid_disk_interface" {
  command = plan

  module {
    source = "../../../modules/proxmox/vm"
  }

  variables {
    node_name         = "pve"
    vmid              = 999
    hostname          = "test-disk"
    ip_address        = "192.168.50.199"
    memory            = 2048
    cores             = 1
    disk_size         = 16
    description       = "Invalid disk interface test"
    network_gateway   = "192.168.50.1"
    dns_servers       = ["192.168.50.1"]
    managed_vmid_min  = 100
    managed_vmid_max  = 999
    datastore_id      = "local-lvm"
    clone_template_id = 9000
    disk_interface    = "nvme0"
  }

  expect_failures = [
    var.disk_interface,
  ]
}

# Node not in cluster triggers lifecycle precondition failure
run "test_invalid_node_name" {
  command = plan

  module {
    source = "../../../modules/proxmox/vm"
  }

  variables {
    node_name         = "nonexistent-node"
    vmid              = 999
    hostname          = "test-node"
    ip_address        = "192.168.50.199"
    memory            = 2048
    cores             = 1
    disk_size         = 16
    description       = "Invalid node name test"
    network_gateway   = "192.168.50.1"
    dns_servers       = ["192.168.50.1"]
    managed_vmid_min  = 100
    managed_vmid_max  = 999
    datastore_id      = "local-lvm"
    clone_template_id = 9000
  }

  expect_failures = [
    proxmox_virtual_environment_vm.this,
  ]
}

# Empty dns_servers list triggers var.dns_servers validation
run "test_empty_dns_servers" {
  command = plan

  module {
    source = "../../../modules/proxmox/vm"
  }

  variables {
    node_name         = "pve"
    vmid              = 999
    hostname          = "test-vm"
    ip_address        = "192.168.50.199"
    memory            = 2048
    cores             = 1
    disk_size         = 16
    description       = "Empty DNS servers test"
    network_gateway   = "192.168.50.1"
    dns_servers       = []
    managed_vmid_min  = 100
    managed_vmid_max  = 999
    datastore_id      = "local-lvm"
    clone_template_id = 9000
  }

  expect_failures = [
    var.dns_servers,
  ]
}
