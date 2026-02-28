# ============================================================================
# Slack workspace variable validation tests
# ============================================================================
#
# Validates variable constraints in 320-slack/.
# Convention: one run block per invalid input, expect_failures = [var.X].
# All tests are plan-only with mocked providers.
# ============================================================================

mock_provider "slack" {}
mock_provider "onepassword" {}

override_module {
  target = module.onepassword_secrets
  outputs = {
    secrets = {
      slack_bot_token = "xoxb-mock-token" # pragma: allowlist secret
    }
    metadata = {
      vault_name = "homelab"
    }
  }
}

# --- onepassword_vault_name: must not be empty ---

run "onepassword_vault_name_empty" {
  command = plan

  module {
    source = "../../../320-slack"
  }

  variables {
    onepassword_vault_name = ""
  }

  expect_failures = [var.onepassword_vault_name]
}

# --- slack_bot_token: must start with 'xox' when provided ---

run "slack_bot_token_invalid_prefix" {
  command = plan

  module {
    source = "../../../320-slack"
  }

  variables {
    slack_bot_token = "invalid-token"
  }

  expect_failures = [var.slack_bot_token]
}

# --- slack_bot_token: xoxp- prefix is valid (relaxed validation accepts xox*) ---

run "slack_bot_token_xoxp_prefix" {
  command = plan

  module {
    source = "../../../320-slack"
  }

  variables {
    slack_bot_token = "xoxp-user-token"
  }
}

# --- slack_bot_token: xoxe. prefix is valid ---

run "slack_bot_token_xoxe_prefix" {
  command = plan

  module {
    source = "../../../320-slack"
  }

  variables {
    slack_bot_token = "xoxe.xoxp-1-abc123"
  }
}

# --- slack_bot_token: empty string is valid (falls back to 1Password) ---

run "slack_bot_token_empty_is_valid" {
  command = plan

  module {
    source = "../../../320-slack"
  }

  variables {
    slack_bot_token = ""
  }
}

# --- slack_bot_token: valid xoxb- prefix ---

run "slack_bot_token_valid" {
  command = plan

  module {
    source = "../../../320-slack"
  }

  variables {
    slack_bot_token = "xoxb-1234567890-abcdef"
  }
}
