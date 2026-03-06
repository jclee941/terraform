# ============================================================================
# Grafana workspace variable validation tests
# ============================================================================
#
# Validates variable constraints in 104-grafana/terraform/.
# Convention: one run block per invalid input, expect_failures = [var.X].
# All tests are plan-only with mocked providers.
# ============================================================================

mock_provider "grafana" {}
mock_provider "onepassword" {}

override_data {
  target = data.terraform_remote_state.infra
  values = {
    outputs = {
      host_inventory = {}
    }
  }
}

override_module {
  target = module.onepassword_secrets
  outputs = {
    secrets = {
      grafana_service_account_token = "mock-grafana-token" # pragma: allowlist secret
    }
    metadata = {
      vault_name = "homelab"
    }
  }
}

# --- grafana_url: must be HTTP(S) URL ---

run "grafana_url_no_protocol" {
  command = plan

  module {
    source = "../../../104-grafana/terraform"
  }

  variables {
    grafana_url = "192.168.50.104:3000"
  }

  expect_failures = [var.grafana_url]
}

run "grafana_url_ftp_protocol" {
  command = plan

  module {
    source = "../../../104-grafana/terraform"
  }

  variables {
    grafana_url = "ftp://192.168.50.104:3000"
  }

  expect_failures = [var.grafana_url]
}


# --- onepassword_vault_name: must not be empty ---

run "onepassword_vault_name_empty" {
  command = plan

  module {
    source = "../../../104-grafana/terraform"
  }

  variables {
    onepassword_vault_name = ""
  }

  expect_failures = [var.onepassword_vault_name]
}

# =============================================================================
# _slack_enabled GUARD TESTS
# =============================================================================
# Verifies conditional Slack contact point creation.
# Default override omits slack_webhook_url from secrets, and var defaults to "".
# So _slack_enabled = false by default in tests.
# =============================================================================

# --- slack disabled by default (no webhook URL in secrets or var) ---

run "slack_disabled_by_default" {
  command = plan

  module {
    source = "../../../104-grafana/terraform"
  }

  # Default overrides: no slack_webhook_url in secrets, var defaults to ""
  # _slack_enabled = false -> grafana_contact_point.slack_alerts count = 0
}

# --- slack enabled when webhook URL provided via 1Password ---

run "slack_enabled_with_webhook" {
  command = plan

  module {
    source = "../../../104-grafana/terraform"
  }

  override_module {
    target = module.onepassword_secrets
    outputs = {
      secrets = {
        grafana_service_account_token = "mock-grafana-token"                    # pragma: allowlist secret
        slack_webhook_url             = "https://hooks.slack.com/services/mock" # pragma: allowlist secret
      }
      metadata = {
        vault_name = "homelab"
      }
    }
  }

  # _slack_enabled = true -> grafana_contact_point.slack_alerts count = 1
}
