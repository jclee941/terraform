mock_provider "synology" {
  mock_data "synology_core_network" {
    defaults = {
      server_name   = "synology-nas"
      dns_primary   = "192.168.50.1"
      dns_secondary = "1.1.1.1"
      gateway       = "192.168.50.1"
    }
  }
}

mock_provider "onepassword" {}

override_module {
  target = module.onepassword_secrets
  outputs = {
    secrets = {              # pragma: allowlist secret # gitleaks:allow
      synology_user     = "" # pragma: allowlist secret # gitleaks:allow
      synology_password = "" # pragma: allowlist secret # gitleaks:allow
    }
  }
}

run "mailplus_catch_all_routes_to_configured_user" {
  command = plan

  module {
    source = "../../../215-synology"
  }

  variables {
    synology_user           = "test-user" # pragma: allowlist secret # gitleaks:allow
    synology_password       = "test-pass" # pragma: allowlist secret # gitleaks:allow
    mailplus_domain_id      = 7
    mailplus_catch_all_user = "mail-owner"
  }

  assert {
    condition     = synology_api.mailplus_catch_all["primary"].parameters["domain_id"] == "7"
    error_message = "MailPlus catch-all must target the configured domain ID"
  }

  assert {
    condition = jsondecode(
      synology_api.mailplus_catch_all["primary"].parameters["catch_all"]
      ) == {
      enable  = true
      setting = "mail-owner"
    }
    error_message = "MailPlus catch-all must route unmatched addresses to the configured DSM user"
  }
}

run "mailplus_catch_all_user_rejects_email_address" {
  command = plan

  module {
    source = "../../../215-synology"
  }

  variables {
    synology_user           = "test-user" # pragma: allowlist secret # gitleaks:allow
    synology_password       = "test-pass" # pragma: allowlist secret # gitleaks:allow
    mailplus_catch_all_user = "user@example.test"
  }

  expect_failures = [var.mailplus_catch_all_user]
}

run "synology_host_requires_https" {
  command = plan

  variables {
    synology_host = "http://192.168.50.215:5001"
  }

  expect_failures = [var.synology_host]
}

run "synology_network_output_is_available" {
  command = plan

  variables {
    synology_host = "https://192.168.50.215:5001"
  }

  assert {
    condition     = output.service_url == "https://192.168.50.215:5001"
    error_message = "service_url output must expose the validated Synology HTTPS endpoint"
  }
}
