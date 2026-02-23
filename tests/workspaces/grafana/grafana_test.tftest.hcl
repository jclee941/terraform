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

# --- n8n_webhook_url: must be HTTP(S) URL ---

run "n8n_webhook_url_no_protocol" {
  command = plan

  module {
    source = "../../../104-grafana/terraform"
  }

  variables {
    n8n_webhook_url = "192.168.50.112:5678/webhook/grafana-alert"
  }

  expect_failures = [var.n8n_webhook_url]
}

run "n8n_webhook_url_ftp_protocol" {
  command = plan

  module {
    source = "../../../104-grafana/terraform"
  }

  variables {
    n8n_webhook_url = "ftp://192.168.50.112:5678/webhook/grafana-alert"
  }

  expect_failures = [var.n8n_webhook_url]
}

# --- n8n_glitchtip_webhook_url: must be HTTP(S) URL ---

run "n8n_glitchtip_webhook_url_no_protocol" {
  command = plan

  module {
    source = "../../../104-grafana/terraform"
  }

  variables {
    n8n_glitchtip_webhook_url = "192.168.50.112:5678/webhook/grafana-to-glitchtip"
  }

  expect_failures = [var.n8n_glitchtip_webhook_url]
}

run "n8n_glitchtip_webhook_url_ftp_protocol" {
  command = plan

  module {
    source = "../../../104-grafana/terraform"
  }

  variables {
    n8n_glitchtip_webhook_url = "ftp://192.168.50.112:5678/webhook/grafana-to-glitchtip"
  }

  expect_failures = [var.n8n_glitchtip_webhook_url]
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
