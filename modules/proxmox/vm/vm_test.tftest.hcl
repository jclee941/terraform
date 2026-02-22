# Tests for modules/proxmox/vm
# Validates variable constraints and module configuration.
# Uses mock_provider to avoid requiring actual Proxmox credentials.

mock_provider "proxmox" {}

variables {
  node_name         = "pve"
  vmid              = 101
  hostname          = "test-vm"
  ip_address        = "192.168.50.101"
  memory            = 2048
  cores             = 2
  disk_size         = 32
  description       = "Test VM"
  network_gateway   = "192.168.50.1"
  dns_servers       = ["192.168.50.1"]
  datastore_id      = "local-lvm"
  managed_vmid_min  = 100
  managed_vmid_max  = 999
  clone_template_id = 9000
}

# --- Valid input tests ---

run "valid_defaults" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_vm.this.name == "test-vm"
    error_message = "VM name should match hostname variable."
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.vm_id == 101
    error_message = "VM ID should match vmid variable."
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.node_name == "pve"
    error_message = "Node name should match node_name variable."
  }
}

run "valid_bios_ovmf" {
  command = plan

  variables {
    bios    = "ovmf"
    machine = "q35"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.bios == "ovmf"
    error_message = "BIOS should accept 'ovmf'."
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.machine == "q35"
    error_message = "Machine type should accept 'q35'."
  }
}

# --- Validation failure tests ---

run "invalid_vmid_too_low" {
  command = plan

  variables {
    vmid = 50
  }

  expect_failures = [
    var.vmid,
  ]
}

run "invalid_vmid_too_high" {
  command = plan

  variables {
    vmid = 1000
  }

  expect_failures = [
    var.vmid,
  ]
}

run "invalid_hostname_uppercase" {
  command = plan

  variables {
    hostname = "InvalidHost"
  }

  expect_failures = [
    var.hostname,
  ]
}

run "invalid_ip_address_with_cidr" {
  command = plan

  variables {
    ip_address = "192.168.50.200/24"
  }

  expect_failures = [
    var.ip_address,
  ]
}

run "invalid_memory_too_low" {
  command = plan

  variables {
    memory = 256
  }

  expect_failures = [
    var.memory,
  ]
}

run "invalid_disk_size_too_small" {
  command = plan

  variables {
    disk_size = 4
  }

  expect_failures = [
    var.disk_size,
  ]
}

run "invalid_bios_type" {
  command = plan

  variables {
    bios = "uefi"
  }

  expect_failures = [
    var.bios,
  ]
}

run "invalid_machine_type" {
  command = plan

  variables {
    machine = "arm64"
  }

  expect_failures = [
    var.machine,
  ]
}

run "invalid_disk_interface" {
  command = plan

  variables {
    disk_interface = "nvme0"
  }

  expect_failures = [
    var.disk_interface,
  ]
}

run "empty_node_name" {
  command = plan

  variables {
    node_name = ""
  }

  expect_failures = [
    var.node_name,
  ]
}

run "empty_dns_servers" {
  command = plan

  variables {
    dns_servers = []
  }

  expect_failures = [
    var.dns_servers,
  ]
}
