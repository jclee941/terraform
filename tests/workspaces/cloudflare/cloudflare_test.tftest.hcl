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

# =============================================================================
# Negative Tests — invalid inputs that must fail validation
# =============================================================================

# --- cloudflare_account_id validation (hex32) ---

run "test_invalid_account_id_too_short" {
  command = plan

  module {
    source = "../../../300-cloudflare"
  }

  variables {
    cloudflare_account_id = "abcdef0123456789"
    cloudflare_zone_id    = "1234567890abcdef1234567890abcdef"
    synology_domain       = "nas.jclee.me"
    access_allowed_emails = ["admin@example.com"]
  }

  expect_failures = [
    var.cloudflare_account_id,
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
    access_allowed_emails = ["admin@example.com"]
  }

  expect_failures = [
    var.cloudflare_account_id,
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
    access_allowed_emails = ["admin@example.com"]
  }

  expect_failures = [
    var.cloudflare_account_id,
  ]
}

# --- cloudflare_zone_id validation (hex32) ---

run "test_invalid_zone_id_too_long" {
  command = plan

  module {
    source = "../../../300-cloudflare"
  }

  variables {
    cloudflare_account_id = "abcdef0123456789abcdef0123456789"
    cloudflare_zone_id    = "1234567890abcdef1234567890abcdef00"
    synology_domain       = "nas.jclee.me"
    access_allowed_emails = ["admin@example.com"]
  }

  expect_failures = [
    var.cloudflare_zone_id,
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
    access_allowed_emails = ["admin@example.com"]
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
    access_allowed_emails = ["admin@example.com"]
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
    access_allowed_emails = ["admin@example.com"]
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
    access_allowed_emails = ["admin@example.com"]
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
    access_allowed_emails = ["admin@example.com"]
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
    access_allowed_emails = ["admin@example.com"]
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
    access_allowed_emails = ["admin@example.com"]
    homelab_domain        = "JCLEE.ME"
  }

  expect_failures = [
    var.homelab_domain,
  ]
}

# --- r2_cache_ttl_days validation (> 0) ---

run "test_invalid_r2_cache_ttl_zero" {
  command = plan

  module {
    source = "../../../300-cloudflare"
  }

  variables {
    cloudflare_account_id = "abcdef0123456789abcdef0123456789"
    cloudflare_zone_id    = "1234567890abcdef1234567890abcdef"
    synology_domain       = "nas.jclee.me"
    access_allowed_emails = ["admin@example.com"]
    r2_cache_ttl_days     = 0
  }

  expect_failures = [
    var.r2_cache_ttl_days,
  ]
}

run "test_invalid_r2_cache_ttl_negative" {
  command = plan

  module {
    source = "../../../300-cloudflare"
  }

  variables {
    cloudflare_account_id = "abcdef0123456789abcdef0123456789"
    cloudflare_zone_id    = "1234567890abcdef1234567890abcdef"
    synology_domain       = "nas.jclee.me"
    access_allowed_emails = ["admin@example.com"]
    r2_cache_ttl_days     = -1
  }

  expect_failures = [
    var.r2_cache_ttl_days,
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
    access_allowed_emails       = ["admin@example.com"]
    cloudflare_secrets_store_id = ""
  }

  expect_failures = [
    var.cloudflare_secrets_store_id,
  ]
}
