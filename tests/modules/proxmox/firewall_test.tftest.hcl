# Firewall Module Tests
# Module: modules/proxmox/firewall (requires bpg/proxmox provider)
# Tests validate LXC/VM ID routing and rule construction with a mocked provider.

mock_provider "proxmox" {
  override_resource {
    target = proxmox_virtual_environment_firewall_rules.this
    values = {
      id = "mock-firewall-rules"
    }
  }

  override_resource {
    target = proxmox_virtual_environment_firewall_options.this
    values = {
      id = "mock-firewall-options"
    }
  }
}

run "test_container_firewall_targets_use_container_id" {
  command = plan

  module {
    source = "../../../modules/proxmox/firewall"
  }

  variables {
    node_name = "pve"
    targets = {
      test_lxc = {
        vmid = 101
        rules = [
          { dport = "22", proto = "tcp", comment = "SSH" },
          { dport = "53", proto = "udp", comment = "DNS (UDP)" },
        ]
      }
    }
    egress_rules = [
      { dest = "192.168.50.0/24", proto = "tcp", dport = null, comment = "Local subnet (TCP)" },
    ]
    target_kind = "container"
  }

  assert {
    condition     = contains(keys(output.container_ids), "test_lxc") && output.container_ids["test_lxc"] == 101
    error_message = "Container firewall targets must set container_id from the target VMID"
  }

  assert {
    condition     = length(output.vm_ids) == 0
    error_message = "Container firewall targets must leave vm_id unset"
  }

  assert {
    condition     = output.rule_counts == { test_lxc = 3 }
    error_message = "Container firewall rules must include all input rules plus common egress rules"
  }
}

run "test_vm_firewall_targets_use_vm_id" {
  command = plan

  module {
    source = "../../../modules/proxmox/firewall"
  }

  variables {
    node_name = "pve"
    targets = {
      test_vm = {
        vmid = 220
        rules = [
          { dport = "443", proto = "tcp", comment = "HTTPS ingress" },
        ]
      }
    }
    egress_rules = [
      { dest = null, proto = "tcp", dport = "443", comment = "HTTPS outbound" },
    ]
    target_kind = "vm"
  }

  assert {
    condition     = contains(keys(output.vm_ids), "test_vm") && output.vm_ids["test_vm"] == 220
    error_message = "VM firewall targets must set vm_id from the target VMID"
  }

  assert {
    condition     = length(output.container_ids) == 0
    error_message = "VM firewall targets must leave container_id unset"
  }

  assert {
    condition     = output.rule_counts == { test_vm = 2 }
    error_message = "VM firewall rules must include all input rules plus common egress rules"
  }
}
