# LXC Module Tests
# Module: modules/proxmox/lxc (requires bpg/proxmox provider)
# Tests validate input validation rules (preconditions) using mock provider.
# Full resource creation requires a live Proxmox connection.

mock_provider "proxmox" {
  override_data {
    target = data.proxmox_virtual_environment_nodes.nodes
    values = {
      names = ["pve"]
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
    proxmox_virtual_environment_container.this,
  ]
}

# VMID above managed range triggers precondition failure
run "test_vmid_above_range" {
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

# Memory below 256 MB triggers precondition failure
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
    proxmox_virtual_environment_container.this,
  ]
}
