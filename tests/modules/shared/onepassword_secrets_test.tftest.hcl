# 1Password Secrets Module Tests
# Module: modules/shared/onepassword-secrets
# Tests validate output structure and try() defaults using mock provider.
# No live 1Password connection required.

mock_provider "onepassword" {
  override_data {
    target = data.onepassword_vault.this
    values = {
      uuid = "mock-vault-uuid"
      name = "homelab"
    }
  }

  override_data {
    target = data.onepassword_item.this["grafana"]
    values = {
      title       = "grafana"
      section_map = {}
    }
  }

  override_data {
    target = data.onepassword_item.this["proxmox"]
    values = {
      title       = "proxmox"
      credential  = ""
      section_map = {}
    }
  }

  override_data {
    target = data.onepassword_item.this["github"]
    values = {
      title       = "github"
      credential  = ""
      section_map = {}
    }
  }



  override_data {
    target = data.onepassword_item.this["supabase"]
    values = {
      title       = "supabase"
      section_map = {}
    }
  }

  override_data {
    target = data.onepassword_item.this["archon"]
    values = {
      title       = "archon"
      section_map = {}
    }
  }

  override_data {
    target = data.onepassword_item.this["cloudflare"]
    values = {
      title       = "cloudflare"
      section_map = {}
    }
  }

  override_data {
    target = data.onepassword_item.this["mcphub"]
    values = {
      title       = "mcphub"
      section_map = {}
    }
  }

  override_data {
    target = data.onepassword_item.this["elk"]
    values = {
      title       = "elk"
      section_map = {}
    }
  }

  override_data {
    target = data.onepassword_item.this["synology"]
    values = {
      title       = "synology"
      section_map = {}
    }
  }

  override_data {
    target = data.onepassword_item.this["youtube"]
    values = {
      title       = "youtube"
      section_map = {}
    }
  }

  override_data {
    target = data.onepassword_item.this["gcp"]
    values = {
      title       = "gcp"
      section_map = {}
    }
  }

  override_data {
    target = data.onepassword_item.this["telegram"]
    values = {
      title       = "telegram"
      credential  = ""
      section_map = {}
    }
  }


}

# --- Output structure tests ---

run "test_secrets_default_to_empty_string" {
  command = plan

  module {
    source = "../../../modules/shared/onepassword-secrets"
  }

  variables {
    vault_name = "homelab"
  }

  # --- Proxmox (2 keys) ---
  assert {
    condition     = output.secrets.proxmox_api_token_value == ""
    error_message = "proxmox_api_token_value should default to empty string"
  }
  assert {
    condition     = output.secrets.proxmox_ssh_private_key == ""
    error_message = "proxmox_ssh_private_key should default to empty string"
  }

  # --- GitHub (1 key) ---
  assert {
    condition     = output.secrets.github_personal_access_token == ""
    error_message = "github_personal_access_token should default to empty string"
  }



  # --- Telegram (1 key) ---
  assert {
    condition     = output.secrets.telegram_bot_token == ""
    error_message = "telegram_bot_token should default to empty string"
  }


  # --- Cloudflare (4 keys) ---
  assert {
    condition     = output.secrets.cloudflare_api_key == ""
    error_message = "cloudflare_api_key should default to empty string"
  }
  assert {
    condition     = output.secrets.cloudflare_api_token == ""
    error_message = "cloudflare_api_token should default to empty string"
  }
  assert {
    condition     = output.secrets.cloudflare_tunnel_token == ""
    error_message = "cloudflare_tunnel_token should default to empty string"
  }
  assert {
    condition     = output.secrets.google_oauth_client_id == ""
    error_message = "google_oauth_client_id should default to empty string"
  }
  assert {
    condition     = output.secrets.google_oauth_client_secret == ""
    error_message = "google_oauth_client_secret should default to empty string"
  }

  # --- MCPHub (4 keys) ---
  assert {
    condition     = output.secrets.mcphub_proxmox_token_name == ""
    error_message = "mcphub_proxmox_token_name should default to empty string"
  }
  assert {
    condition     = output.secrets.mcphub_proxmox_token_value == ""
    error_message = "mcphub_proxmox_token_value should default to empty string"
  }
  assert {
    condition     = output.secrets.mcphub_admin_password == ""
    error_message = "mcphub_admin_password should default to empty string"
  }
  assert {
    condition     = output.secrets.mcphub_op_service_account_token == ""
    error_message = "mcphub_op_service_account_token should default to empty string"
  }

  # --- ELK (2 keys) ---
  assert {
    condition     = output.secrets.elk_elastic_password == ""
    error_message = "elk_elastic_password should default to empty string"
  }
  assert {
    condition     = output.secrets.elk_kibana_password == ""
    error_message = "elk_kibana_password should default to empty string"
  }

  # --- Synology (2 keys) ---
  assert {
    condition     = output.secrets.synology_user == ""
    error_message = "synology_user should default to empty string"
  }
  assert {
    condition     = output.secrets.synology_password == ""
    error_message = "synology_password should default to empty string"
  }

  # --- YouTube (3 keys) ---
  assert {
    condition     = output.secrets.youtube_google_client_id == ""
    error_message = "youtube_google_client_id should default to empty string"
  }
  assert {
    condition     = output.secrets.youtube_google_client_secret == ""
    error_message = "youtube_google_client_secret should default to empty string"
  }
  assert {
    condition     = output.secrets.youtube_google_refresh_token == ""
    error_message = "youtube_google_refresh_token should default to empty string"
  }

  # --- GCP (1 key) ---
  assert {
    condition     = output.secrets.gcp_credentials == ""
    error_message = "gcp_credentials should default to empty string"
  }
}

# All metadata keys default to "" when section_map is empty (try() fallback)
run "test_metadata_default_to_empty_string" {
  command = plan

  module {
    source = "../../../modules/shared/onepassword-secrets"
  }

  variables {
    vault_name = "homelab"
  }

  # --- Cloudflare (3 keys) ---
  assert {
    condition     = output.metadata.cloudflare_email == ""
    error_message = "cloudflare_email should default to empty string"
  }
  assert {
    condition     = output.metadata.cloudflare_account_id == ""
    error_message = "cloudflare_account_id should default to empty string"
  }
  assert {
    condition     = output.metadata.cloudflare_zone_id == ""
    error_message = "cloudflare_zone_id should default to empty string"
  }

  # --- YouTube (2 keys) ---
  assert {
    condition     = output.metadata.youtube_google_project_id == ""
    error_message = "youtube_google_project_id should default to empty string"
  }
  assert {
    condition     = output.metadata.youtube_channel_id == ""
    error_message = "youtube_channel_id should default to empty string"
  }

  # --- GCP (2 keys) ---
  assert {
    condition     = output.metadata.gcp_project_id == ""
    error_message = "gcp_project_id should default to empty string"
  }
  assert {
    condition     = output.metadata.gcp_region == ""
    error_message = "gcp_region should default to empty string"
  }
}

run "test_connection_info_default_to_empty_string" {
  command = plan

  module {
    source = "../../../modules/shared/onepassword-secrets"
  }

  variables {
    vault_name = "homelab"
  }

  assert {
    condition     = output.connection_info.proxmox_endpoint == ""
    error_message = "proxmox_endpoint should default to empty string"
  }
  assert {
    condition     = output.connection_info.cloudflare_account_id == ""
    error_message = "cloudflare_account_id should default to empty string"
  }
  assert {
    condition     = output.connection_info.gcp_region == ""
    error_message = "gcp_region should default to empty string"
  }
}

run "test_secrets_key_count" {
  command = plan

  module {
    source = "../../../modules/shared/onepassword-secrets"
  }

  variables {
    vault_name = "homelab"
  }

  assert {
    condition     = length(output.secrets) == 26
    error_message = "Secrets output should contain exactly 26 keys, got ${nonsensitive(length(output.secrets))}"
  }
}

# Verify metadata output contains exactly 11 keys
run "test_metadata_key_count" {
  command = plan

  module {
    source = "../../../modules/shared/onepassword-secrets"
  }

  variables {
    vault_name = "homelab"
  }

  assert {
    condition     = length(output.metadata) == 11
    error_message = "Metadata output should contain exactly 11 keys, got ${length(output.metadata)}"
  }
}

run "test_connection_info_key_count" {
  command = plan

  module {
    source = "../../../modules/shared/onepassword-secrets"
  }

  variables {
    vault_name = "homelab"
  }

  assert {
    condition     = length(output.connection_info) == 12
    error_message = "connection_info output should contain exactly 12 keys, got ${length(output.connection_info)}"
  }
}

# Verify every expected secret key name exists in the output map
run "test_all_secret_key_names_exist" {
  command = plan

  module {
    source = "../../../modules/shared/onepassword-secrets"
  }

  variables {
    vault_name = "homelab"
  }

  # Proxmox
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "proxmox_api_token_value")
    error_message = "Missing secret key: proxmox_api_token_value"
  }
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "proxmox_ssh_private_key")
    error_message = "Missing secret key: proxmox_ssh_private_key"
  }

  # GitHub
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "github_personal_access_token")
    error_message = "Missing secret key: github_personal_access_token"
  }



  # Telegram
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "telegram_bot_token")
    error_message = "Missing secret key: telegram_bot_token"
  }

  # Cloudflare
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "cloudflare_api_key")
    error_message = "Missing secret key: cloudflare_api_key"
  }
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "cloudflare_api_token")
    error_message = "Missing secret key: cloudflare_api_token"
  }
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "cloudflare_tunnel_token")
    error_message = "Missing secret key: cloudflare_tunnel_token"
  }
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "google_oauth_client_id")
    error_message = "Missing secret key: google_oauth_client_id"
  }
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "google_oauth_client_secret")
    error_message = "Missing secret key: google_oauth_client_secret"
  }

  # MCPHub
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "mcphub_proxmox_token_name")
    error_message = "Missing secret key: mcphub_proxmox_token_name"
  }
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "mcphub_proxmox_token_value")
    error_message = "Missing secret key: mcphub_proxmox_token_value"
  }
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "mcphub_admin_password")
    error_message = "Missing secret key: mcphub_admin_password"
  }
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "mcphub_op_service_account_token")
    error_message = "Missing secret key: mcphub_op_service_account_token"
  }

  # ELK
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "elk_elastic_password")
    error_message = "Missing secret key: elk_elastic_password"
  }
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "elk_kibana_password")
    error_message = "Missing secret key: elk_kibana_password"
  }

  # PBS
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "pbs_password")
    error_message = "Missing secret key: pbs_password"
  }

  # Synology
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "synology_user")
    error_message = "Missing secret key: synology_user"
  }
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "synology_password")
    error_message = "Missing secret key: synology_password"
  }

  # YouTube
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "youtube_google_client_id")
    error_message = "Missing secret key: youtube_google_client_id"
  }
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "youtube_google_client_secret")
    error_message = "Missing secret key: youtube_google_client_secret"
  }
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "youtube_google_refresh_token")
    error_message = "Missing secret key: youtube_google_refresh_token"
  }

  # GCP
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "gcp_credentials")
    error_message = "Missing secret key: gcp_credentials"
  }
  assert {
    condition     = contains(keys(output.connection_info), "gcp_project_id")
    error_message = "Missing connection_info key: gcp_project_id"
  }
  assert {
    condition     = contains(keys(output.connection_info), "gcp_region")
    error_message = "Missing connection_info key: gcp_region"
  }
}

run "test_all_connection_info_key_names_exist" {
  command = plan

  module {
    source = "../../../modules/shared/onepassword-secrets"
  }

  variables {
    vault_name = "homelab"
  }

  assert {
    condition     = contains(keys(output.connection_info), "proxmox_endpoint")
    error_message = "Missing connection_info key: proxmox_endpoint"
  }
  assert {
    condition     = contains(keys(output.connection_info), "cloudflare_email")
    error_message = "Missing connection_info key: cloudflare_email"
  }
  assert {
    condition     = contains(keys(output.connection_info), "cloudflare_account_id")
    error_message = "Missing connection_info key: cloudflare_account_id"
  }
  assert {
    condition     = contains(keys(output.connection_info), "cloudflare_zone_id")
    error_message = "Missing connection_info key: cloudflare_zone_id"
  }
}

# Verify every expected metadata key name exists in the output map
run "test_all_metadata_key_names_exist" {
  command = plan

  module {
    source = "../../../modules/shared/onepassword-secrets"
  }

  variables {
    vault_name = "homelab"
  }

  # Cloudflare
  assert {
    condition     = contains(keys(output.metadata), "cloudflare_email")
    error_message = "Missing metadata key: cloudflare_email"
  }
  assert {
    condition     = contains(keys(output.metadata), "cloudflare_account_id")
    error_message = "Missing metadata key: cloudflare_account_id"
  }
  assert {
    condition     = contains(keys(output.metadata), "cloudflare_zone_id")
    error_message = "Missing metadata key: cloudflare_zone_id"
  }

  # PBS
  assert {
    condition     = contains(keys(output.metadata), "pbs_server")
    error_message = "Missing metadata key: pbs_server"
  }
  assert {
    condition     = contains(keys(output.metadata), "pbs_datastore")
    error_message = "Missing metadata key: pbs_datastore"
  }
  assert {
    condition     = contains(keys(output.metadata), "pbs_username")
    error_message = "Missing metadata key: pbs_username"
  }
  assert {
    condition     = contains(keys(output.metadata), "pbs_fingerprint")
    error_message = "Missing metadata key: pbs_fingerprint"
  }

  # YouTube
  assert {
    condition     = contains(keys(output.metadata), "youtube_google_project_id")
    error_message = "Missing metadata key: youtube_google_project_id"
  }
  assert {
    condition     = contains(keys(output.metadata), "youtube_channel_id")
    error_message = "Missing metadata key: youtube_channel_id"
  }

  # GCP
  assert {
    condition     = contains(keys(output.metadata), "gcp_project_id")
    error_message = "Missing metadata key: gcp_project_id"
  }
  assert {
    condition     = contains(keys(output.metadata), "gcp_region")
    error_message = "Missing metadata key: gcp_region"
  }
}

# Verify no overlap between secrets and metadata keys
run "test_no_key_overlap" {
  command = plan

  module {
    source = "../../../modules/shared/onepassword-secrets"
  }

  variables {
    vault_name = "homelab"
  }

  assert {
    condition     = length(setintersection(nonsensitive(keys(output.secrets)), keys(output.metadata))) == 0
    error_message = "Secrets and metadata outputs must not share any keys"
  }
}

# Verify default vault_name is used when not specified
run "test_default_vault_name" {
  command = plan

  module {
    source = "../../../modules/shared/onepassword-secrets"
  }

  # No variables block — vault_name defaults to "homelab"

  assert {
    condition     = length(output.secrets) + length(output.metadata) + length(output.connection_info) == 49
    error_message = "Total keys (secrets + metadata + connection_info) should equal 49"
  }
}
