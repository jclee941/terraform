# Tests for modules/shared/vault-agent
# Validates variable constraints, policy generation, and AppRole setup.
# Uses mock_provider to avoid requiring actual Vault credentials.

mock_provider "vault" {}
mock_provider "local" {}

variables {
  service_name = "mcphub"
  vault_addr   = "https://vault.jclee.me"
  vault_mount  = "secret"
  kv_path      = "homelab/mcphub"
}

# --- Valid input tests ---

run "valid_defaults" {
  command = plan

  assert {
    condition     = vault_policy.service.name == "mcphub-agent"
    error_message = "Policy name should be '{service_name}-agent'."
  }

  assert {
    condition     = vault_approle_auth_backend_role.service.role_name == "mcphub-agent"
    error_message = "AppRole role name should be '{service_name}-agent'."
  }

  assert {
    condition     = vault_approle_auth_backend_role.service.token_ttl == 3600
    error_message = "Default token TTL should be 3600."
  }

  assert {
    condition     = vault_approle_auth_backend_role.service.token_max_ttl == 14400
    error_message = "Default token max TTL should be 14400."
  }
}

run "custom_ttl" {
  command = plan

  variables {
    token_ttl     = 7200
    token_max_ttl = 28800
  }

  assert {
    condition     = vault_approle_auth_backend_role.service.token_ttl == 7200
    error_message = "Custom token TTL should be 7200."
  }

  assert {
    condition     = vault_approle_auth_backend_role.service.token_max_ttl == 28800
    error_message = "Custom token max TTL should be 28800."
  }
}

run "no_approle_backend_by_default" {
  command = plan

  assert {
    condition     = length(vault_auth_backend.approle) == 0
    error_message = "AppRole backend should not be created by default."
  }
}

run "create_approle_backend" {
  command = plan

  variables {
    create_approle_backend = true
  }

  assert {
    condition     = length(vault_auth_backend.approle) == 1
    error_message = "AppRole backend should be created when create_approle_backend is true."
  }
}

# --- Validation failure tests ---

run "invalid_service_name_uppercase" {
  command = plan

  variables {
    service_name = "MyService"
  }

  expect_failures = [
    var.service_name,
  ]
}

run "invalid_service_name_starts_with_number" {
  command = plan

  variables {
    service_name = "1invalid"
  }

  expect_failures = [
    var.service_name,
  ]
}

run "invalid_vault_addr" {
  command = plan

  variables {
    vault_addr = "not-a-url"
  }

  expect_failures = [
    var.vault_addr,
  ]
}

run "empty_vault_mount" {
  command = plan

  variables {
    vault_mount = ""
  }

  expect_failures = [
    var.vault_mount,
  ]
}

run "invalid_kv_path_special_chars" {
  command = plan

  variables {
    kv_path = "path with spaces"
  }

  expect_failures = [
    var.kv_path,
  ]
}

run "empty_approle_backend_path" {
  command = plan

  variables {
    approle_backend_path = ""
  }

  expect_failures = [
    var.approle_backend_path,
  ]
}
