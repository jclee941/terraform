# ============================================================================
# Archon workspace output smoke tests
# ============================================================================

override_data {
  target = data.terraform_remote_state.infra
  values = {
    outputs = {
      host_inventory = {
        archon = {
          hostname = "archon"
          ip       = "192.168.50.108"
          vmid     = 108
        }
      }
    }
  }
}

run "archon_inventory_loaded" {
  command = plan

  module {
    source = "../../../108-archon/terraform"
  }

  assert {
    condition     = output.host_inventory_loaded
    error_message = "host_inventory_loaded must be true when remote host inventory is present"
  }
}
