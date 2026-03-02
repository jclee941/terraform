# ============================================================================
# Archon workspace tests
# ============================================================================
# Validates the 108-archon workspace configuration.
# This workspace only consumes remote state from 100-pve — no providers.
# ============================================================================

# --- Remote state override ------------------------------------------------

override_data {
  target = data.terraform_remote_state.infra
  values = {
    outputs = {
      host_inventory = {
        "108" = {
          hostname  = "archon"
          ip        = "192.168.50.108"
          type      = "lxc"
          host_id   = 108
          domain    = "jclee.me"
          host_tags = ["archon", "ai"]
        }
      }
    }
  }
}

# --- Test: plan succeeds with mock remote state ---------------------------

run "archon_plan_succeeds" {
  command = plan
  module {
    source = "../../../108-archon/terraform"
  }
}

# --- Test: plan succeeds with empty host inventory ------------------------

run "archon_empty_inventory" {
  command = plan
  module {
    source = "../../../108-archon/terraform"
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
