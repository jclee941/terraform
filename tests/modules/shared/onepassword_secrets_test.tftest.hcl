# 1Password Secrets Module Tests
# Module: modules/shared/onepassword-secrets
# Tests validate output structure and try() defaults using mock provider.
# No live 1Password connection required.

mock_provider "onepassword" {
  override_data {
    target = data.onepassword_vault.this
    values = {
      uuid = "mock-vault-uuid"
      name = "Homelab"
    }
  }

  override_data {
    target = data.onepassword_item.grafana
    values = {
      title       = "grafana"
      section_map = {}
    }
  }

  override_data {
    target = data.onepassword_item.glitchtip
    values = {
      title       = "glitchtip"
      section_map = {}
    }
  }

  override_data {
    target = data.onepassword_item.proxmox
    values = {
      title       = "proxmox"
      section_map = {}
    }
  }

  override_data {
    target = data.onepassword_item.github
    values = {
      title       = "github"
      section_map = {}
    }
  }

  override_data {
    target = data.onepassword_item.exa
    values = {
      title       = "exa"
      section_map = {}
    }
  }

  override_data {
    target = data.onepassword_item.splunk
    values = {
      title       = "splunk"
      section_map = {}
    }
  }

  override_data {
    target = data.onepassword_item.supabase
    values = {
      title       = "supabase"
      section_map = {}
    }
  }

  override_data {
    target = data.onepassword_item.archon
    values = {
      title       = "archon"
      section_map = {}
    }
  }

  override_data {
    target = data.onepassword_item.cloudflare
    values = {
      title       = "cloudflare"
      section_map = {}
    }
  }

  override_data {
    target = data.onepassword_item.n8n
    values = {
      title       = "n8n"
      section_map = {}
    }
  }

  override_data {
    target = data.onepassword_item.mcphub
    values = {
      title       = "mcphub"
      section_map = {}
    }
  }

  override_data {
    target = data.onepassword_item.elk
    values = {
      title       = "elk"
      section_map = {}
    }
  }
}

# --- Output structure tests ---

# All secret keys default to "" when section_map is empty (try() fallback)
run "test_secrets_default_to_empty_string" {
  command = plan

  module {
    source = "../../../modules/shared/onepassword-secrets"
  }

  variables {
    vault_name = "Homelab"
  }

  # Secrets output
  assert {
    condition     = output.secrets.grafana_admin_password == ""
    error_message = "Grafana admin_password should default to empty string"
  }

  assert {
    condition     = output.secrets.elk_elastic_password == ""
    error_message = "ELK elastic_password should default to empty string"
  }

  assert {
    condition     = output.secrets.mcphub_admin_password == ""
    error_message = "MCPHub admin_password should default to empty string"
  }

  assert {
    condition     = output.secrets.cloudflare_api_key == ""
    error_message = "Cloudflare api_key should default to empty string"
  }

  assert {
    condition     = output.secrets.proxmox_api_token_value == ""
    error_message = "Proxmox api_token_value should default to empty string"
  }

  # Metadata output
  assert {
    condition     = output.metadata.splunk_host == ""
    error_message = "Splunk host should default to empty string"
  }

  assert {
    condition     = output.metadata.splunk_port == ""
    error_message = "Splunk port should default to empty string"
  }

  assert {
    condition     = output.metadata.cloudflare_email == ""
    error_message = "Cloudflare email should default to empty string"
  }

  assert {
    condition     = output.metadata.cloudflare_account_id == ""
    error_message = "Cloudflare account_id should default to empty string"
  }
}

# Verify secrets output contains expected key count (31 secret keys)
run "test_secrets_key_count" {
  command = plan

  module {
    source = "../../../modules/shared/onepassword-secrets"
  }

  variables {
    vault_name = "Homelab"
  }

  assert {
    condition     = length(output.secrets) == 27
    error_message = "Secrets output should contain exactly 27 keys, got ${nonsensitive(length(output.secrets))}"
  }
}

# Verify metadata output contains expected key count (8 metadata keys)
run "test_metadata_key_count" {
  command = plan

  module {
    source = "../../../modules/shared/onepassword-secrets"
  }

  variables {
    vault_name = "Homelab"
  }

  assert {
    condition     = length(output.metadata) == 8
    error_message = "Metadata output should contain exactly 8 keys, got ${length(output.metadata)}"
  }
}

# Verify no overlap between secrets and metadata keys
run "test_no_key_overlap" {
  command = plan

  module {
    source = "../../../modules/shared/onepassword-secrets"
  }

  variables {
    vault_name = "Homelab"
  }

  assert {
    condition     = length(setintersection(keys(output.secrets), keys(output.metadata))) == 0
    error_message = "Secrets and metadata outputs must not share any keys"
  }
}

# Verify default vault_name is used when not specified
run "test_default_vault_name" {
  command = plan

  module {
    source = "../../../modules/shared/onepassword-secrets"
  }

  # No variables block — vault_name defaults to "Homelab"

  assert {
    condition     = length(output.secrets) + length(output.metadata) == 35
    error_message = "Total keys (secrets + metadata) should equal 35"
  }
}
