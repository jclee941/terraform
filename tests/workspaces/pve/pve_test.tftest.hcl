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
    secrets = {                                       # pragma: allowlist secret
      mcphub_admin_password           = "mock-secret" # pragma: allowlist secret
      mcphub_n8n_mcp_api_key          = "mock-secret" # pragma: allowlist secret
      mcphub_op_service_account_token = "mock-secret" # pragma: allowlist secret
      mcphub_proxmox_token_name       = "mock-secret" # pragma: allowlist secret
      mcphub_proxmox_token_value      = "mock-secret" # pragma: allowlist secret
      elk_elastic_password            = "mock-secret" # pragma: allowlist secret
      elk_kibana_password             = "mock-secret" # pragma: allowlist secret
      github_personal_access_token    = "mock-secret" # pragma: allowlist secret
      glitchtip_api_token             = "mock-secret" # pragma: allowlist secret
      glitchtip_django_secret_key     = "mock-secret" # pragma: allowlist secret
      glitchtip_postgres_password     = "mock-secret" # pragma: allowlist secret
      glitchtip_redis_password        = "mock-secret" # pragma: allowlist secret
      openai_api_key                  = "mock-secret" # pragma: allowlist secret
      proxmox_ssh_private_key         = "mock-secret" # pragma: allowlist secret
      slack_mcp_xoxb_token            = "mock-secret" # pragma: allowlist secret
      slack_mcp_xoxp_token            = "mock-secret" # pragma: allowlist secret
      supabase_anon_key               = "mock-secret" # pragma: allowlist secret
      supabase_dashboard_password     = "mock-secret" # pragma: allowlist secret
      supabase_db_password            = "mock-secret" # pragma: allowlist secret
      supabase_jwt_secret             = "mock-secret" # pragma: allowlist secret
      supabase_service_role_key       = "mock-secret" # pragma: allowlist secret
      grafana_admin_password          = "mock-secret" # pragma: allowlist secret
      grafana_service_account_token   = "mock-secret" # pragma: allowlist secret
      proxmox_api_token_value         = "mock-secret" # pragma: allowlist secret
      exa_api_key                     = "mock-secret" # pragma: allowlist secret
      supabase_service_key            = "mock-secret" # pragma: allowlist secret
      archon_anthropic_key            = "mock-secret" # pragma: allowlist secret
      cloudflare_api_key              = "mock-secret" # pragma: allowlist secret
      n8n_api_key                     = "mock-secret" # pragma: allowlist secret
      n8n_github_token                = "mock-secret" # pragma: allowlist secret
      n8n_glitchtip_api_token         = "mock-secret" # pragma: allowlist secret
    }
    metadata = {
      splunk_username             = "admin"
      splunk_host                 = "192.168.50.215"
      splunk_port                 = "8089"
      supabase_url                = "https://supabase.jclee.me"
      supabase_dashboard_username = "admin"
      cloudflare_email            = "test@example.com"
      cloudflare_account_id       = "abcdef0123456789abcdef0123456789"
      cloudflare_zone_id          = "1234567890abcdef1234567890abcdef"
    }
  }
}


# =============================================================================
# NEGATIVE TESTS — Invalid Variable Values
# =============================================================================

# --- proxmox_endpoint: must start with https:// ---

run "test_endpoint_http_rejected" {
  command = plan
  module {
    source = "../../../100-pve"
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
    source = "../../../100-pve"
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
    source = "../../../100-pve"
  }
  variables {
    proxmox_api_token = "terraform!tf-token=12345678"
  }
  expect_failures = [var.proxmox_api_token]
}

run "test_api_token_missing_equals_rejected" {
  command = plan
  module {
    source = "../../../100-pve"
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
    source = "../../../100-pve"
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
    source = "../../../100-pve"
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
    source = "../../../100-pve"
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
    source = "../../../100-pve"
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
    source = "../../../100-pve"
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
    source = "../../../100-pve"
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
    source = "../../../100-pve"
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
    source = "../../../100-pve"
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
    source = "../../../100-pve"
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
    source = "../../../100-pve"
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
    source = "../../../100-pve"
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
    source = "../../../100-pve"
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
    source = "../../../100-pve"
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
    source = "../../../100-pve"
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
    source = "../../../100-pve"
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
    source = "../../../100-pve"
  }
  variables {
    proxmox_api_token = "terraform@pam!tf-token=12345678-1234-1234-1234-123456789abc"
    ssh_public_keys   = ["dsa-key AAAAB3NzaC1kc3MAAACBAP user@host"]
  }
  expect_failures = [var.ssh_public_keys]
}
