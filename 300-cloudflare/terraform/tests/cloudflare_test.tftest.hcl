# Cloudflare Workspace Variable Validation Tests
# Workspace: 300-cloudflare (Cloudflare DNS, Tunnel, Access, R2, Secrets)
# Tests validate variable validation rules using mock providers.
# Run: terraform -chdir=300-cloudflare/terraform test -filter=tests/cloudflare_test.tftest.hcl

# ---------------------------------------------------------------------------
# Mock Providers — prevent real API calls during plan-only tests
# ---------------------------------------------------------------------------

mock_provider "cloudflare" {
  mock_resource "cloudflare_dns_record" {
    defaults = {
      comment_modified_on = "2026-07-23T00:00:00Z"
      created_on          = "2026-07-23T00:00:00Z"
      id                  = "00000000000000000000000000000000"
      meta                = "{}"
      modified_on         = "2026-07-23T00:00:00Z"
      proxiable           = true
      tags_modified_on    = "2026-07-23T00:00:00Z"
    }
  }
  override_resource {
    target          = cloudflare_dns_record.tcp_services["code"]
    override_during = plan
    values = {
      content             = "mock.cfargotunnel.com"
      id                  = "mock-dns-code"
      meta                = "{}"
      name                = "code.jclee.me"
      type                = "CNAME"
      ttl                 = 1
      zone_id             = "1234567890abcdef1234567890abcdef"
      comment             = ""
      data                = null
      priority            = null
      proxied             = true
      created_on          = "2026-07-23T00:00:00Z"
      modified_on         = "2026-07-23T00:00:00Z"
      proxiable           = true
      tags                = []
      settings            = { flatten_cname = false, ipv4_only = false, ipv6_only = false }
      comment_modified_on = null
      tags_modified_on    = null
    }
  }

  override_resource {
    target          = cloudflare_dns_record.direct["grafana"]
    override_during = plan
    values = {
      content             = "mock.cfargotunnel.com"
      id                  = "mock-dns-grafana"
      meta                = "{}"
      name                = "grafana.jclee.me"
      type                = "CNAME"
      ttl                 = 1
      zone_id             = "1234567890abcdef1234567890abcdef"
      comment             = ""
      data                = null
      priority            = null
      proxied             = true
      created_on          = "2026-07-23T00:00:00Z"
      modified_on         = "2026-07-23T00:00:00Z"
      proxiable           = true
      tags                = []
      settings            = { flatten_cname = false, ipv4_only = false, ipv6_only = false }
      comment_modified_on = null
      tags_modified_on    = null
    }
  }

  override_resource {
    target          = cloudflare_dns_record.direct["idle"]
    override_during = plan
    values = {
      content             = "mock.cfargotunnel.com"
      id                  = "mock-dns-idle"
      meta                = "{}"
      name                = "idle.jclee.me"
      type                = "CNAME"
      ttl                 = 1
      zone_id             = "1234567890abcdef1234567890abcdef"
      comment             = ""
      data                = null
      priority            = null
      proxied             = true
      created_on          = "2026-07-23T00:00:00Z"
      modified_on         = "2026-07-23T00:00:00Z"
      proxiable           = true
      tags                = []
      settings            = { flatten_cname = false, ipv4_only = false, ipv6_only = false }
      comment_modified_on = null
      tags_modified_on    = null
    }
  }

  override_resource {
    target          = cloudflare_dns_record.direct["youtube"]
    override_during = plan
    values = {
      content             = "mock.cfargotunnel.com"
      id                  = "mock-dns-youtube"
      meta                = "{}"
      name                = "youtube.jclee.me"
      type                = "CNAME"
      ttl                 = 1
      zone_id             = "1234567890abcdef1234567890abcdef"
      comment             = ""
      data                = null
      priority            = null
      proxied             = true
      created_on          = "2026-07-23T00:00:00Z"
      modified_on         = "2026-07-23T00:00:00Z"
      proxiable           = true
      tags                = []
      settings            = { flatten_cname = false, ipv4_only = false, ipv6_only = false }
      comment_modified_on = null
      tags_modified_on    = null
    }
  }

}
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

override_module {
  target = module.tunnels["homelab"]
  outputs = {
    tunnel_id = "00000000-0000-0000-0000-000000000000"
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

# --- onepassword_vault_name: must not be empty ---

run "test_onepassword_vault_name_empty" {
  command = plan

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

  variables {
    cloudflare_account_id = "abcdef0123456789abcdef0123456789"
    cloudflare_zone_id    = "1234567890abcdef1234567890abcdef"
    synology_domain       = "nas.jclee.me"
    youtube_ip            = "not-an-ip"
  }

  expect_failures = [var.youtube_ip]
}

run "test_public_logstash_ingress_is_retired" {
  command = plan

  variables {
    cloudflare_account_id = "abcdef0123456789abcdef0123456789"
    cloudflare_zone_id    = "1234567890abcdef1234567890abcdef"
    synology_domain       = "nas.jclee.me"
  }

  assert {
    condition     = module.onepassword_secrets.metadata.vault_name == "homelab" && !can(regex("logstash-ingest", file("dns.tf")))
    error_message = "Cloudflare DNS must not publish logstash-ingest."
  }

  assert {
    condition     = module.onepassword_secrets.metadata.vault_name == "homelab" && !can(regex("logstash-ingest|:8080", file("tunnel.tf")))
    error_message = "Cloudflare Tunnel must not route public traffic to Logstash HTTP ingest."
  }

  assert {
    condition     = module.onepassword_secrets.metadata.vault_name == "homelab" && !fileexists("logpush.tf")
    error_message = "The retired Cloudflare Logpush job must not remain configured."
  }

  assert {
    condition     = module.onepassword_secrets.metadata.vault_name == "homelab" && can(regex("beats\\s*\\{[\\s\\S]*port\\s*=>\\s*5044", file("../../105-elk/templates/logstash.conf.tftpl")))
    error_message = "Private Filebeat ingestion must remain configured on port 5044."
  }
}
