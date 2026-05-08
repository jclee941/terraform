# Cloudflare Workspace Variable Validation Tests
# Workspace: 300-cloudflare (Cloudflare DNS, Tunnel, Access, R2, Secrets)
# Tests validate variable validation rules using mock providers.
# Run: terraform test (from tests/workspaces/cloudflare)

# ---------------------------------------------------------------------------
# Mock Providers — prevent real API calls during plan-only tests
# ---------------------------------------------------------------------------

mock_provider "cloudflare" {}
mock_provider "github" {}
mock_provider "random" {}
mock_provider "onepassword" {}
mock_provider "time" {}

override_module {
  target = module.onepassword_secrets
  outputs = {
    secrets = {
      cloudflare_api_token         = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" # pragma: allowlist secret
      github_personal_access_token = "mock-github-token"                        # pragma: allowlist secret
    }
    metadata = {
      vault_name       = "homelab"
      cloudflare_email = "admin@example.com"
    }
  }
}


# =============================================================================
# Negative Tests — invalid inputs that must fail validation
# =============================================================================

# --- cloudflare_account_id validation (hex32, via runtime precondition) ---
# Validation moved from variable block to terraform_data.validate_credentials
# precondition since 1Password integration makes the variable optional.

run "test_invalid_account_id_too_short" {
  command = plan

  module {
    source = "../../../300-cloudflare"
  }

  variables {
    cloudflare_account_id = "abcdef0123456789"
    cloudflare_zone_id    = "1234567890abcdef1234567890abcdef"
    synology_domain       = "nas.jclee.me"
  }

  expect_failures = [
    terraform_data.validate_credentials,
  ]
}

run "test_invalid_account_id_uppercase" {
  command = plan

  module {
    source = "../../../300-cloudflare"
  }

  variables {
    cloudflare_account_id = "ABCDEF0123456789ABCDEF0123456789"
    cloudflare_zone_id    = "1234567890abcdef1234567890abcdef"
    synology_domain       = "nas.jclee.me"
  }

  expect_failures = [
    terraform_data.validate_credentials,
  ]
}

run "test_invalid_account_id_special_chars" {
  command = plan

  module {
    source = "../../../300-cloudflare"
  }

  variables {
    cloudflare_account_id = "abcdef0123456789abcdef012345678!"
    cloudflare_zone_id    = "1234567890abcdef1234567890abcdef"
    synology_domain       = "nas.jclee.me"
  }

  expect_failures = [
    terraform_data.validate_credentials,
  ]
}

# --- cloudflare_zone_id validation (hex32, via runtime precondition) ---

run "test_invalid_zone_id_too_long" {
  command = plan

  module {
    source = "../../../300-cloudflare"
  }

  variables {
    cloudflare_account_id = "abcdef0123456789abcdef0123456789"
    cloudflare_zone_id    = "1234567890abcdef1234567890abcdef00"
    synology_domain       = "nas.jclee.me"
  }

  expect_failures = [
    terraform_data.validate_credentials,
  ]
}

# --- synology_domain validation (domain name) ---

run "test_invalid_synology_domain_starts_with_dot" {
  command = plan

  module {
    source = "../../../300-cloudflare"
  }

  variables {
    cloudflare_account_id = "abcdef0123456789abcdef0123456789"
    cloudflare_zone_id    = "1234567890abcdef1234567890abcdef"
    synology_domain       = ".nas.jclee.me"
  }

  expect_failures = [
    var.synology_domain,
  ]
}

run "test_invalid_synology_domain_ends_with_dot" {
  command = plan

  module {
    source = "../../../300-cloudflare"
  }

  variables {
    cloudflare_account_id = "abcdef0123456789abcdef0123456789"
    cloudflare_zone_id    = "1234567890abcdef1234567890abcdef"
    synology_domain       = "nas.jclee.me."
  }

  expect_failures = [
    var.synology_domain,
  ]
}

# --- synology_nas_ip validation (IPv4) ---

run "test_invalid_synology_ip_with_cidr" {
  command = plan

  module {
    source = "../../../300-cloudflare"
  }

  variables {
    cloudflare_account_id = "abcdef0123456789abcdef0123456789"
    cloudflare_zone_id    = "1234567890abcdef1234567890abcdef"
    synology_domain       = "nas.jclee.me"
    synology_nas_ip       = "192.168.50.215/24"
  }

  expect_failures = [
    var.synology_nas_ip,
  ]
}

run "test_invalid_synology_ip_not_ip" {
  command = plan

  module {
    source = "../../../300-cloudflare"
  }

  variables {
    cloudflare_account_id = "abcdef0123456789abcdef0123456789"
    cloudflare_zone_id    = "1234567890abcdef1234567890abcdef"
    synology_domain       = "nas.jclee.me"
    synology_nas_ip       = "not-an-ip"
  }

  expect_failures = [
    var.synology_nas_ip,
  ]
}

# --- synology_nas_port validation (1-65535) ---

run "test_invalid_synology_port_zero" {
  command = plan

  module {
    source = "../../../300-cloudflare"
  }

  variables {
    cloudflare_account_id = "abcdef0123456789abcdef0123456789"
    cloudflare_zone_id    = "1234567890abcdef1234567890abcdef"
    synology_domain       = "nas.jclee.me"
    synology_nas_port     = 0
  }

  expect_failures = [
    var.synology_nas_port,
  ]
}

run "test_invalid_synology_port_too_high" {
  command = plan

  module {
    source = "../../../300-cloudflare"
  }

  variables {
    cloudflare_account_id = "abcdef0123456789abcdef0123456789"
    cloudflare_zone_id    = "1234567890abcdef1234567890abcdef"
    synology_domain       = "nas.jclee.me"
    synology_nas_port     = 65536
  }

  expect_failures = [
    var.synology_nas_port,
  ]
}

# --- homelab_domain validation (domain name) ---

run "test_invalid_homelab_domain_uppercase" {
  command = plan

  module {
    source = "../../../300-cloudflare"
  }

  variables {
    cloudflare_account_id = "abcdef0123456789abcdef0123456789"
    cloudflare_zone_id    = "1234567890abcdef1234567890abcdef"
    synology_domain       = "nas.jclee.me"
    homelab_domain        = "JCLEE.ME"
  }

  expect_failures = [
    var.homelab_domain,
  ]
}


# --- cloudflare_secrets_store_id validation (hex32) ---

run "test_invalid_secrets_store_id_empty" {
  command = plan

  module {
    source = "../../../300-cloudflare"
  }

  variables {
    cloudflare_account_id       = "abcdef0123456789abcdef0123456789"
    cloudflare_zone_id          = "1234567890abcdef1234567890abcdef"
    synology_domain             = "nas.jclee.me"
    cloudflare_secrets_store_id = ""
  }

  expect_failures = [
    var.cloudflare_secrets_store_id,
  ]
}

# --- github_token: must be empty or start with ghp_ / github_pat_ ---

run "test_github_token_invalid_prefix" {
  command = plan

  module {
    source = "../../../300-cloudflare"
  }

  variables {
    cloudflare_account_id = "abcdef0123456789abcdef0123456789"
    cloudflare_zone_id    = "1234567890abcdef1234567890abcdef"
    synology_domain       = "nas.jclee.me"
    github_token          = "gho_invalid_prefix_token"
  }

  expect_failures = [var.github_token]
}

# --- onepassword_vault_name: must not be empty ---

run "test_onepassword_vault_name_empty" {
  command = plan

  module {
    source = "../../../300-cloudflare"
  }

  variables {
    cloudflare_account_id  = "abcdef0123456789abcdef0123456789"
    cloudflare_zone_id     = "1234567890abcdef1234567890abcdef"
    synology_domain        = "nas.jclee.me"
    onepassword_vault_name = ""
  }

  expect_failures = [var.onepassword_vault_name]
}


# --- jclee_ip: must be valid IPv4 ---

run "test_jclee_ip_invalid" {
  command = plan

  module {
    source = "../../../300-cloudflare"
  }

  variables {
    cloudflare_account_id = "abcdef0123456789abcdef0123456789"
    cloudflare_zone_id    = "1234567890abcdef1234567890abcdef"
    synology_domain       = "nas.jclee.me"
    jclee_ip              = "not-an-ip"
  }

  expect_failures = [var.jclee_ip]
}

# --- jclee_dev_ip: must be valid IPv4 ---

run "test_jclee_dev_ip_invalid" {
  command = plan

  module {
    source = "../../../300-cloudflare"
  }

  variables {
    cloudflare_account_id = "abcdef0123456789abcdef0123456789"
    cloudflare_zone_id    = "1234567890abcdef1234567890abcdef"
    synology_domain       = "nas.jclee.me"
    jclee_dev_ip          = "not-an-ip"
  }

  expect_failures = [var.jclee_dev_ip]
}

# --- elk_ip: must be valid IPv4 ---

run "test_elk_ip_invalid" {
  command = plan

  module {
    source = "../../../300-cloudflare"
  }

  variables {
    cloudflare_account_id = "abcdef0123456789abcdef0123456789"
    cloudflare_zone_id    = "1234567890abcdef1234567890abcdef"
    synology_domain       = "nas.jclee.me"
    elk_ip                = "not-an-ip"
  }

  expect_failures = [var.elk_ip]
}

# --- youtube_ip: must be valid IPv4 ---

run "test_youtube_ip_invalid" {
  command = plan

  module {
    source = "../../../300-cloudflare"
  }

  variables {
    cloudflare_account_id = "abcdef0123456789abcdef0123456789"
    cloudflare_zone_id    = "1234567890abcdef1234567890abcdef"
    synology_domain       = "nas.jclee.me"
    youtube_ip            = "not-an-ip"
  }

  expect_failures = [var.youtube_ip]
}
