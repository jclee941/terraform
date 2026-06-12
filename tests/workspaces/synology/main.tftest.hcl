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

mock_provider "minio" {}

override_module {
  target = module.onepassword_secrets
  outputs = {
    secrets = {                    # pragma: allowlist secret
      synology_user           = "" # pragma: allowlist secret
      synology_password       = "" # pragma: allowlist secret
      registry_minio_user     = "" # pragma: allowlist secret
      registry_minio_password = "" # pragma: allowlist secret
    }
  }
}

# Pin minio_iam_user_policy_attachment.console_admin count behavior so a future
# refactor of the upstream condition (count = var.minio_console_admin_password != "" ? 1 : 0)
# cannot regress the empty/non-empty password symmetry.

run "minio_console_admin_policy_attachment_skipped_when_password_empty" {
  command = plan

  module {
    source = "../../../215-synology"
  }

  variables {
    enable_registry              = false
    synology_user                = "test-user" # pragma: allowlist secret
    synology_password            = "test-pass" # pragma: allowlist secret
    minio_console_admin_password = ""
  }

  assert {
    condition     = length(minio_iam_user_policy_attachment.console_admin) == 0
    error_message = "minio_iam_user_policy_attachment.console_admin must be empty when minio_console_admin_password is empty"
  }
}

run "minio_console_admin_policy_attachment_created_when_password_set" {
  command = plan

  module {
    source = "../../../215-synology"
  }

  variables {
    enable_registry              = false
    synology_user                = "test-user"           # pragma: allowlist secret
    synology_password            = "test-pass"           # pragma: allowlist secret
    minio_console_admin_password = "test-admin-password" # pragma: allowlist secret
  }

  assert {
    condition     = length(minio_iam_user_policy_attachment.console_admin) == 1
    error_message = "minio_iam_user_policy_attachment.console_admin must exist when minio_console_admin_password is non-empty"
  }
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
