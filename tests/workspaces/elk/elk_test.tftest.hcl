# ============================================================================
# ELK workspace variable validation tests
# ============================================================================
#
# Validates variable constraints in 105-elk/terraform/.
# Convention: one run block per invalid input, expect_failures = [var.X].
# All tests are plan-only with mocked providers.
# ============================================================================

mock_provider "elasticstack" {}
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
      elk_elastic_password = "mock-elastic-password" # pragma: allowlist secret
    }
    metadata = {
      vault_name = "homelab"
    }
  }
}

# --- elasticsearch_url: must be HTTP(S) URL ---

run "elasticsearch_url_no_protocol" {
  command = plan

  module {
    source = "../../../105-elk/terraform"
  }

  variables {
    elasticsearch_url = "192.168.50.105:9200"
  }

  expect_failures = [var.elasticsearch_url]
}

run "elasticsearch_url_ftp_protocol" {
  command = plan

  module {
    source = "../../../105-elk/terraform"
  }

  variables {
    elasticsearch_url = "ftp://192.168.50.105:9200"
  }

  expect_failures = [var.elasticsearch_url]
}

# --- kibana_url: must be HTTP(S) URL ---

run "kibana_url_no_protocol" {
  command = plan

  module {
    source = "../../../105-elk/terraform"
  }

  variables {
    kibana_url = "192.168.50.105:5601"
  }

  expect_failures = [var.kibana_url]
}

run "kibana_url_ftp_protocol" {
  command = plan

  module {
    source = "../../../105-elk/terraform"
  }

  variables {
    kibana_url = "ftp://192.168.50.105:5601"
  }

  expect_failures = [var.kibana_url]
}

# --- onepassword_vault_name: must not be empty ---

run "onepassword_vault_name_empty" {
  command = plan

  module {
    source = "../../../105-elk/terraform"
  }

  variables {
    onepassword_vault_name = ""
  }

  expect_failures = [var.onepassword_vault_name]
}
