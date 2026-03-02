# ============================================================================
# Ollama workspace tests
# ============================================================================
# Validates the 109-ollama workspace configuration.
# This workspace only consumes remote state from 100-pve — no providers.
# Output: host_inventory_loaded = length(local.hosts) > 0
# ============================================================================

# --- Remote state override ------------------------------------------------

override_data {
  target = data.terraform_remote_state.infra
  values = {
    outputs = {
      host_inventory = {
        "109" = {
          hostname  = "ollama"
          ip        = "192.168.50.109"
          type      = "vm"
          host_id   = 109
          domain    = "jclee.me"
          host_tags = ["ollama", "ai", "gpu"]
        }
      }
    }
  }
}

# --- Test: plan succeeds with mock remote state ---------------------------

run "ollama_plan_succeeds" {
  command = plan
  module {
    source = "../../../109-ollama/terraform"
  }

  assert {
    condition     = output.host_inventory_loaded == true
    error_message = "host_inventory_loaded should be true when hosts exist"
  }
}

# --- Test: plan succeeds with empty host inventory ------------------------

run "ollama_empty_inventory" {
  command = plan
  module {
    source = "../../../109-ollama/terraform"
  }

  override_data {
    target = data.terraform_remote_state.infra
    values = {
      outputs = {
        host_inventory = {}
      }
    }
  }

  assert {
    condition     = output.host_inventory_loaded == false
    error_message = "host_inventory_loaded should be false when no hosts exist"
  }
}
