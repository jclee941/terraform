# Tests for modules/shared/vault-secrets
# Validates module configuration and Vault KV v2 data source setup.
# Uses mock_provider to avoid requiring actual Vault credentials.

mock_provider "vault" {}

variables {
  vault_mount = "secret"
}

run "default_mount" {
  command = plan

  assert {
    condition     = data.vault_kv_secret_v2.grafana.mount == "secret"
    error_message = "Default vault_mount should be 'secret'."
  }

  assert {
    condition     = data.vault_kv_secret_v2.grafana.name == "homelab/grafana"
    error_message = "Grafana secret path should be 'homelab/grafana'."
  }
}

run "custom_mount" {
  command = plan

  variables {
    vault_mount = "kv"
  }

  assert {
    condition     = data.vault_kv_secret_v2.grafana.mount == "kv"
    error_message = "Custom vault_mount should be respected."
  }
}

run "all_secret_paths" {
  command = plan

  assert {
    condition     = data.vault_kv_secret_v2.elk.name == "homelab/elk"
    error_message = "ELK secret path should be 'homelab/elk'."
  }

  assert {
    condition     = data.vault_kv_secret_v2.cloudflare.name == "homelab/cloudflare"
    error_message = "Cloudflare secret path should be 'homelab/cloudflare'."
  }

  assert {
    condition     = data.vault_kv_secret_v2.mcphub.name == "homelab/mcphub"
    error_message = "MCPHub secret path should be 'homelab/mcphub'."
  }

  assert {
    condition     = data.vault_kv_secret_v2.n8n.name == "homelab/n8n"
    error_message = "n8n secret path should be 'homelab/n8n'."
  }

  assert {
    condition     = data.vault_kv_secret_v2.supabase.name == "homelab/supabase"
    error_message = "Supabase secret path should be 'homelab/supabase'."
  }
}
