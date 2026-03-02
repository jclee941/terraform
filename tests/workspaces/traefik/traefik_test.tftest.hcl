# ============================================================================
# Traefik workspace tests
# ============================================================================
# Validates the 102-traefik workspace configuration.
# This workspace only consumes remote state from 100-pve — no providers.
# ============================================================================

# --- Remote state override ------------------------------------------------

override_data {
  target = data.terraform_remote_state.infra
  values = {
    outputs = {
      host_inventory = {
        "102" = {
          hostname  = "traefik"
          ip        = "192.168.50.102"
          type      = "lxc"
          host_id   = 102
          domain    = "jclee.me"
          host_tags = ["proxy", "traefik"]
        }
      }
    }
  }
}

# --- Test: plan succeeds with mock remote state ---------------------------

run "traefik_plan_succeeds" {
  command = plan
  module {
    source = "../../../102-traefik/terraform"
  }
}

# --- Test: plan succeeds with empty host inventory ------------------------

run "traefik_empty_inventory" {
  command = plan
  module {
    source = "../../../102-traefik/terraform"
  }

  override_data {
    target = data.terraform_remote_state.infra
    values = {
      outputs = {
        host_inventory = {}
      }
    }
  }
}
