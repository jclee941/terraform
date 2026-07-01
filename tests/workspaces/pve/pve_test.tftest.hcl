# =============================================================================
# 100-PVE WORKSPACE VARIABLE VALIDATION TESTS
# =============================================================================
# Tests all 10 validation blocks across 8 variables in 100-pve/variables.tf.
# Plan-only with fully mocked providers — no live Proxmox or 1Password access.
# Only negative (expect_failures) tests: positive plans fail due to resource
# preconditions and check blocks that cannot be satisfied with mock providers.
# =============================================================================

mock_provider "proxmox" {
  mock_data "proxmox_virtual_environment_nodes" {
    defaults = {
      names = ["pve3"]
    }
  }
}
mock_provider "onepassword" {}

override_module {
  target = module.onepassword_secrets
  outputs = {
    secrets = {                                                    # pragma: allowlist secret
      proxmox_api_token_value         = "mock-secret"              # pragma: allowlist secret
      proxmox_ssh_private_key         = "mock-secret"              # pragma: allowlist secret
      mcphub_admin_password           = "mock-secret"              # pragma: allowlist secret
      mcphub_op_service_account_token = "mock-secret"              # pragma: allowlist secret
      mcphub_op_connect_token         = "mock-secret"              # pragma: allowlist secret
      mcphub_proxmox_token_name       = "mock-user@pam!mock-token" # pragma: allowlist secret
      mcphub_proxmox_token_value      = "mock-secret"              # pragma: allowlist secret
      elk_elastic_password            = "mock-secret"              # pragma: allowlist secret
      elk_kibana_password             = "mock-secret"              # pragma: allowlist secret
      github_personal_access_token    = "mock-secret"              # pragma: allowlist secret
      telegram_bot_token              = "mock-secret"              # pragma: allowlist secret
      cloudflare_api_key              = "mock-secret"              # pragma: allowlist secret
      cloudflare_api_token            = "mock-secret"              # pragma: allowlist secret
      traefik_htpasswd_hash           = "mock-secret"              # pragma: allowlist secret
      cloudflare_tunnel_token         = "mock-secret"              # pragma: allowlist secret
      google_oauth_client_id          = "mock-secret"              # pragma: allowlist secret
      google_oauth_client_secret      = "mock-secret"              # pragma: allowlist secret
      pbs_password                    = "mock-secret"              # pragma: allowlist secret
      registry_minio_user             = "test-mc-user"             # pragma: allowlist secret
      registry_minio_password         = "test-mc-pass"             # pragma: allowlist secret
      synology_user                   = "mock-secret"              # pragma: allowlist secret
      synology_password               = "mock-secret"              # pragma: allowlist secret
      youtube_google_client_id        = "mock-secret"              # pragma: allowlist secret
      youtube_google_client_secret    = "mock-secret"              # pragma: allowlist secret
      youtube_google_refresh_token    = "mock-secret"              # pragma: allowlist secret
    }
    metadata = {
      cloudflare_email          = "test@example.com"
      cloudflare_account_id     = "abcdef0123456789abcdef0123456789"
      cloudflare_zone_id        = "1234567890abcdef1234567890abcdef"
      pbs_server                = "192.168.50.200"
      pbs_datastore             = "backup"
      pbs_username              = "backup@pbs"
      pbs_fingerprint           = "aa:bb:cc:dd"
      youtube_google_project_id = "mock-project-id"
      youtube_channel_id        = "mock-channel-id"
    }
  }
}



# --- BuildKit S3 cache credentials: must use registry 1Password secrets ---

run "test_buildkit_minio_credentials_use_registry_secrets" {
  command = plan

  assert {
    condition     = terraform.workspace != "" && !can(regex("minioadmin", file("../../../100-pve/terraform/vm_configs.tf")))
    error_message = "100-pve VM BuildKit S3 cache config must not hardcode minioadmin."
  }

  assert {
    condition     = terraform.workspace != "" && can(regex("registry_minio_user", file("../../../100-pve/terraform/vm_configs.tf"))) && can(regex("registry_minio_password", file("../../../100-pve/terraform/vm_configs.tf")))
    error_message = "100-pve VM BuildKit S3 cache config must reference registry_minio_user and registry_minio_password from 1Password."
  }

  assert {
    condition     = terraform.workspace != "" && can(regex("enable_registry\\s*=\\s*var\\.enable_registry", file("../../../100-pve/terraform/secrets.tf")))
    error_message = "100-pve must pass var.enable_registry into module.onepassword_secrets."
  }
}

# --- registry MinIO guard: a BLOCKING precondition must reject empty/minioadmin creds ---
# A full positive plan of 100-pve cannot complete under mocks (pre-existing template
# rendering depends on live host inventory), so this test statically verifies the guard's
# structure: it is a terraform_data lifecycle precondition (blocking, not a `check` warning)
# gated on enable_registry, and it rejects BOTH user and password being empty or 'minioadmin'.

run "test_registry_guard_is_blocking_and_rejects_minioadmin" {
  command = plan

  # Guard is a blocking lifecycle precondition on a terraform_data resource,
  # NOT a non-blocking `check` block.
  assert {
    condition     = terraform.workspace != "" && can(regex("resource\\s+\"terraform_data\"\\s+\"registry_minio_secrets_guard\"", file("../../../100-pve/terraform/checks.tf")))
    error_message = "registry guard must be a terraform_data resource (blocking) not a check block (warning only)."
  }

  assert {
    condition     = terraform.workspace != "" && can(regex("precondition", file("../../../100-pve/terraform/checks.tf")))
    error_message = "registry guard must use a lifecycle precondition so terraform plan FAILS, not just warns."
  }

  # Guard is gated on enable_registry.
  assert {
    condition     = terraform.workspace != "" && can(regex("count\\s*=\\s*var\\.enable_registry", file("../../../100-pve/terraform/checks.tf")))
    error_message = "registry guard must only apply when enable_registry is true."
  }

  # Guard rejects the insecure 'minioadmin' default for BOTH user AND password.
  assert {
    condition     = terraform.workspace != "" && can(regex("registry_minio_user\", \"\"\\)\\)\\s*!=\\s*\"minioadmin\"", file("../../../100-pve/terraform/checks.tf"))) && can(regex("registry_minio_password\", \"\"\\)\\)\\s*!=\\s*\"minioadmin\"", file("../../../100-pve/terraform/checks.tf")))
    error_message = "registry guard must reject 'minioadmin' for BOTH registry_minio_user and registry_minio_password."
  }

  # Guard requires both creds to be non-empty.
  assert {
    condition     = terraform.workspace != "" && length(regexall("length\\(trimspace\\(lookup\\(module\\.onepassword_secrets\\.secrets, \"registry_minio_(user|password)\", \"\"\\)\\)\\)\\s*>\\s*0", file("../../../100-pve/terraform/checks.tf"))) == 2
    error_message = "registry guard must require both registry_minio_user and registry_minio_password to be non-empty."
  }
}

# =============================================================================
# NEGATIVE TESTS — Invalid Variable Values
# =============================================================================

# --- proxmox_endpoint: must start with https:// ---

run "test_endpoint_http_rejected" {
  command = plan
  module {
    source = "../../../100-pve/terraform"
  }
  variables {
    proxmox_endpoint  = "http://192.168.50.100:8006/"
    proxmox_api_token = "terraform@pam!tf-token=12345678-1234-1234-1234-123456789abc"
  }
  expect_failures = [var.proxmox_endpoint]
}

run "test_endpoint_no_protocol_rejected" {
  command = plan
  module {
    source = "../../../100-pve/terraform"
  }
  variables {
    proxmox_endpoint  = "192.168.50.100:8006"
    proxmox_api_token = "terraform@pam!tf-token=12345678-1234-1234-1234-123456789abc"
  }
  expect_failures = [var.proxmox_endpoint]
}

# --- proxmox_api_token: format user@realm!tokenid=uuid ---

run "test_api_token_missing_realm_rejected" {
  command = plan
  module {
    source = "../../../100-pve/terraform"
  }
  variables {
    proxmox_api_token = "terraform!tf-token=12345678"
  }
  expect_failures = [var.proxmox_api_token]
}

run "test_api_token_missing_equals_rejected" {
  command = plan
  module {
    source = "../../../100-pve/terraform"
  }
  variables {
    proxmox_api_token = "terraform@pam!tf-token"
  }
  expect_failures = [var.proxmox_api_token]
}

# --- node_name: must match ^pve[0-9]+$ ---

run "test_node_name_no_number_rejected" {
  command = plan
  module {
    source = "../../../100-pve/terraform"
  }
  variables {
    proxmox_api_token = "terraform@pam!tf-token=12345678-1234-1234-1234-123456789abc"
    node_name         = "pve"
  }
  expect_failures = [var.node_name]
}

run "test_node_name_wrong_prefix_rejected" {
  command = plan
  module {
    source = "../../../100-pve/terraform"
  }
  variables {
    proxmox_api_token = "terraform@pam!tf-token=12345678-1234-1234-1234-123456789abc"
    node_name         = "node1"
  }
  expect_failures = [var.node_name]
}

run "test_node_name_uppercase_rejected" {
  command = plan
  module {
    source = "../../../100-pve/terraform"
  }
  variables {
    proxmox_api_token = "terraform@pam!tf-token=12345678-1234-1234-1234-123456789abc"
    node_name         = "PVE3"
  }
  expect_failures = [var.node_name]
}

# --- network_gateway: valid IPv4 ---

run "test_gateway_invalid_ip_rejected" {
  command = plan
  module {
    source = "../../../100-pve/terraform"
  }
  variables {
    proxmox_api_token = "terraform@pam!tf-token=12345678-1234-1234-1234-123456789abc"
    network_gateway   = "not-an-ip"
  }
  expect_failures = [var.network_gateway]
}

# --- network_cidr: valid CIDR notation ---

run "test_cidr_no_mask_rejected" {
  command = plan
  module {
    source = "../../../100-pve/terraform"
  }
  variables {
    proxmox_api_token = "terraform@pam!tf-token=12345678-1234-1234-1234-123456789abc"
    network_cidr      = "192.168.50.0"
  }
  expect_failures = [var.network_cidr]
}

run "test_cidr_invalid_notation_rejected" {
  command = plan
  module {
    source = "../../../100-pve/terraform"
  }
  variables {
    proxmox_api_token = "terraform@pam!tf-token=12345678-1234-1234-1234-123456789abc"
    network_cidr      = "not-a-cidr"
  }
  expect_failures = [var.network_cidr]
}

# --- dns_servers: length 1-3 ---

run "test_dns_servers_empty_rejected" {
  command = plan
  module {
    source = "../../../100-pve/terraform"
  }
  variables {
    proxmox_api_token = "terraform@pam!tf-token=12345678-1234-1234-1234-123456789abc"
    dns_servers       = []
  }
  expect_failures = [var.dns_servers]
}

run "test_dns_servers_too_many_rejected" {
  command = plan
  module {
    source = "../../../100-pve/terraform"
  }
  variables {
    proxmox_api_token = "terraform@pam!tf-token=12345678-1234-1234-1234-123456789abc"
    dns_servers       = ["8.8.8.8", "8.8.4.4", "1.1.1.1", "1.0.0.1"]
  }
  expect_failures = [var.dns_servers]
}

# --- datastore_id: starts with letter, alphanum/hyphen/underscore ---

run "test_datastore_starts_with_number_rejected" {
  command = plan
  module {
    source = "../../../100-pve/terraform"
  }
  variables {
    proxmox_api_token = "terraform@pam!tf-token=12345678-1234-1234-1234-123456789abc"
    datastore_id      = "1storage"
  }
  expect_failures = [var.datastore_id]
}

run "test_datastore_special_chars_rejected" {
  command = plan
  module {
    source = "../../../100-pve/terraform"
  }
  variables {
    proxmox_api_token = "terraform@pam!tf-token=12345678-1234-1234-1234-123456789abc"
    datastore_id      = "store@pool"
  }
  expect_failures = [var.datastore_id]
}

# --- managed_vmid_range: min < max AND both within 100-199 ---

run "test_vmid_range_min_equals_max_rejected" {
  command = plan
  module {
    source = "../../../100-pve/terraform"
  }
  variables {
    proxmox_api_token  = "terraform@pam!tf-token=12345678-1234-1234-1234-123456789abc"
    managed_vmid_range = { min = 110, max = 110 }
  }
  expect_failures = [var.managed_vmid_range]
}

run "test_vmid_range_min_greater_than_max_rejected" {
  command = plan
  module {
    source = "../../../100-pve/terraform"
  }
  variables {
    proxmox_api_token  = "terraform@pam!tf-token=12345678-1234-1234-1234-123456789abc"
    managed_vmid_range = { min = 150, max = 110 }
  }
  expect_failures = [var.managed_vmid_range]
}

run "test_vmid_range_below_100_rejected" {
  command = plan
  module {
    source = "../../../100-pve/terraform"
  }
  variables {
    proxmox_api_token  = "terraform@pam!tf-token=12345678-1234-1234-1234-123456789abc"
    managed_vmid_range = { min = 50, max = 150 }
  }
  expect_failures = [var.managed_vmid_range]
}

run "test_vmid_range_above_255_rejected" {
  command = plan
  module {
    source = "../../../100-pve/terraform"
  }
  variables {
    proxmox_api_token  = "terraform@pam!tf-token=12345678-1234-1234-1234-123456789abc"
    managed_vmid_range = { min = 100, max = 300 }
  }
  expect_failures = [var.managed_vmid_range]
}

# --- ssh_public_keys: valid SSH key format ---

run "test_ssh_key_invalid_format_rejected" {
  command = plan
  module {
    source = "../../../100-pve/terraform"
  }
  variables {
    proxmox_api_token = "terraform@pam!tf-token=12345678-1234-1234-1234-123456789abc"
    ssh_public_keys   = ["not-a-valid-ssh-key"]
  }
  expect_failures = [var.ssh_public_keys]
}

run "test_ssh_key_invalid_type_rejected" {
  command = plan
  module {
    source = "../../../100-pve/terraform"
  }
  variables {
    proxmox_api_token = "terraform@pam!tf-token=12345678-1234-1234-1234-123456789abc"
    ssh_public_keys   = ["dsa-key AAAAB3NzaC1kc3MAAACBAP user@host"]
  }
  expect_failures = [var.ssh_public_keys]
}

# --- onepassword_vault_name: must not be empty ---

run "test_onepassword_vault_name_empty_rejected" {
  command = plan
  module {
    source = "../../../100-pve/terraform"
  }
  variables {
    proxmox_api_token      = "terraform@pam!tf-token=12345678-1234-1234-1234-123456789abc"
    onepassword_vault_name = ""
  }
  expect_failures = [var.onepassword_vault_name]
}

# --- github_org: must match ^[a-zA-Z0-9-]+$ ---

run "test_github_org_invalid_chars_rejected" {
  command = plan
  module {
    source = "../../../100-pve/terraform"
  }
  variables {
    proxmox_api_token = "terraform@pam!tf-token=12345678-1234-1234-1234-123456789abc"
    github_org        = "my_org@invalid"
  }
  expect_failures = [var.github_org]
}
