# ============================================================================
# Traefik workspace output smoke tests
# ============================================================================

override_data {
  target = data.terraform_remote_state.infra
  values = {
    outputs = {
      host_inventory = {
        traefik = {
          hostname = "traefik"
          ip       = "192.168.50.102"
          vmid     = 102
        }
      }
    }
  }
}

run "traefik_outputs_are_populated" {
  command = plan

  module {
    source = "../../../102-traefik/terraform"
  }

  assert {
    condition     = output.container_ip == "192.168.50.102"
    error_message = "Traefik container_ip output must come from remote host inventory"
  }

  assert {
    condition     = output.container_id == 102
    error_message = "Traefik container_id output must come from remote host inventory"
  }
}
