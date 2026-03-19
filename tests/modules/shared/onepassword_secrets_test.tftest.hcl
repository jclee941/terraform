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
    target = data.onepassword_item.this["n8n"]
    values = {
      title       = "n8n"
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
    target = data.onepassword_item.this["slack"]
    values = {
      title       = "slack"
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

  # --- Grafana (2 keys) ---
  assert {
    condition     = output.secrets.grafana_admin_password == ""
    error_message = "grafana_admin_password should default to empty string"
  }
  assert {
    condition     = output.secrets.grafana_service_account_token == ""
    error_message = "grafana_service_account_token should default to empty string"
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


  # --- Supabase (6 keys) ---
  assert {
    condition     = output.secrets.supabase_service_key == ""
    error_message = "supabase_service_key should default to empty string"
  }
  assert {
    condition     = output.secrets.supabase_anon_key == ""
    error_message = "supabase_anon_key should default to empty string"
  }
  assert {
    condition     = output.secrets.supabase_service_role_key == ""
    error_message = "supabase_service_role_key should default to empty string"
  }
  assert {
    condition     = output.secrets.supabase_db_password == ""
    error_message = "supabase_db_password should default to empty string"
  }
  assert {
    condition     = output.secrets.supabase_jwt_secret == ""
    error_message = "supabase_jwt_secret should default to empty string"
  }
  assert {
    condition     = output.secrets.supabase_dashboard_password == ""
    error_message = "supabase_dashboard_password should default to empty string"
  }

  # --- Archon (2 keys) ---
  assert {
    condition     = output.secrets.archon_anthropic_key == ""
    error_message = "archon_anthropic_key should default to empty string"
  }
  assert {
    condition     = output.secrets.openai_api_key == ""
    error_message = "openai_api_key should default to empty string"
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

  # --- n8n (2 keys) ---
  assert {
    condition     = output.secrets.n8n_api_key == ""
    error_message = "n8n_api_key should default to empty string"
  }
  assert {
    condition     = output.secrets.n8n_github_token == ""
    error_message = "n8n_github_token should default to empty string"
  }

  # --- MCPHub (5 keys) ---
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
    condition     = output.secrets.mcphub_n8n_mcp_api_key == ""
    error_message = "mcphub_n8n_mcp_api_key should default to empty string"
  }
  assert {
    condition     = output.secrets.mcphub_op_service_account_token == ""
    error_message = "mcphub_op_service_account_token should default to empty string"
  }

  # --- Slack (4 keys) ---
  assert {
    condition     = output.secrets.slack_mcp_xoxp_token == ""
    error_message = "slack_mcp_xoxp_token should default to empty string"
  }
  assert {
    condition     = output.secrets.slack_mcp_xoxb_token == ""
    error_message = "slack_mcp_xoxb_token should default to empty string"
  }
  assert {
    condition     = output.secrets.slack_bot_token == ""
    error_message = "slack_bot_token should default to empty string"
  }
  assert {
    condition     = output.secrets.slack_webhook_url == ""
    error_message = "slack_webhook_url should default to empty string"
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

# All 14 metadata keys default to "" when section_map is empty (try() fallback)
run "test_metadata_default_to_empty_string" {
  command = plan

  module {
    source = "../../../modules/shared/onepassword-secrets"
  }

  variables {
    vault_name = "homelab"
  }

  # --- Supabase (2 keys) ---
  assert {
    condition     = output.metadata.supabase_url == ""
    error_message = "supabase_url should default to empty string"
  }
  assert {
    condition     = output.metadata.supabase_dashboard_username == ""
    error_message = "supabase_dashboard_username should default to empty string"
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

  # --- n8n (1 key) ---
  assert {
    condition     = output.metadata.n8n_webhook_url == ""
    error_message = "n8n_webhook_url should default to empty string"
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
    condition     = output.connection_info.slack_webhook_url == ""
    error_message = "slack_webhook_url should default to empty string"
  }
  assert {
    condition     = output.connection_info.supabase_url == ""
    error_message = "supabase_url should default to empty string"
  }
  assert {
    condition     = output.connection_info.cloudflare_account_id == ""
    error_message = "cloudflare_account_id should default to empty string"
  }
  assert {
    condition     = output.connection_info.n8n_webhook_url == ""
    error_message = "n8n_webhook_url should default to empty string"
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
    condition     = length(output.secrets) == 42
    error_message = "Secrets output should contain exactly 43 keys, got ${nonsensitive(length(output.secrets))}"


  }
}

# Verify metadata output contains exactly 14 keys
run "test_metadata_key_count" {
  command = plan

  module {
    source = "../../../modules/shared/onepassword-secrets"
  }

  variables {
    vault_name = "homelab"
  }

  assert {
    condition     = length(output.metadata) == 14
    error_message = "Metadata output should contain exactly 14 keys, got ${length(output.metadata)}"
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
    condition     = length(output.connection_info) == 16
    error_message = "connection_info output should contain exactly 16 keys, got ${length(output.connection_info)}"
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

  # Grafana
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "grafana_admin_password")
    error_message = "Missing secret key: grafana_admin_password"
  }
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "grafana_service_account_token")
    error_message = "Missing secret key: grafana_service_account_token"
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

  # Supabase
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "supabase_service_key")
    error_message = "Missing secret key: supabase_service_key"
  }
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "supabase_anon_key")
    error_message = "Missing secret key: supabase_anon_key"
  }
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "supabase_service_role_key")
    error_message = "Missing secret key: supabase_service_role_key"
  }
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "supabase_db_password")
    error_message = "Missing secret key: supabase_db_password"
  }
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "supabase_jwt_secret")
    error_message = "Missing secret key: supabase_jwt_secret"
  }
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "supabase_dashboard_password")
    error_message = "Missing secret key: supabase_dashboard_password"
  }

  # Archon
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "archon_anthropic_key")
    error_message = "Missing secret key: archon_anthropic_key"
  }
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "openai_api_key")
    error_message = "Missing secret key: openai_api_key"
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

  # n8n
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "n8n_api_key")
    error_message = "Missing secret key: n8n_api_key"
  }
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "n8n_github_token")
    error_message = "Missing secret key: n8n_github_token"
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
    condition     = contains(nonsensitive(keys(output.secrets)), "mcphub_n8n_mcp_api_key")
    error_message = "Missing secret key: mcphub_n8n_mcp_api_key"
  }
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "mcphub_op_service_account_token")
    error_message = "Missing secret key: mcphub_op_service_account_token"
  }

  # Slack
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "slack_mcp_xoxp_token")
    error_message = "Missing secret key: slack_mcp_xoxp_token"
  }
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "slack_mcp_xoxb_token")
    error_message = "Missing secret key: slack_mcp_xoxb_token"
  }
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "slack_bot_token")
    error_message = "Missing secret key: slack_bot_token"
  }
  assert {
    condition     = contains(nonsensitive(keys(output.secrets)), "slack_webhook_url")
    error_message = "Missing secret key: slack_webhook_url"
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
    condition     = contains(keys(output.connection_info), "slack_webhook_url")
    error_message = "Missing connection_info key: slack_webhook_url"
  }
  assert {
    condition     = contains(keys(output.connection_info), "supabase_url")
    error_message = "Missing connection_info key: supabase_url"
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
  assert {
    condition     = contains(keys(output.connection_info), "n8n_webhook_url")
    error_message = "Missing connection_info key: n8n_webhook_url"
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

  # Supabase
  assert {
    condition     = contains(keys(output.metadata), "supabase_url")
    error_message = "Missing metadata key: supabase_url"
  }
  assert {
    condition     = contains(keys(output.metadata), "supabase_dashboard_username")
    error_message = "Missing metadata key: supabase_dashboard_username"
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

  # n8n
  assert {
    condition     = contains(keys(output.metadata), "n8n_webhook_url")
    error_message = "Missing metadata key: n8n_webhook_url"
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
    condition     = length(output.secrets) + length(output.metadata) + length(output.connection_info) == 72
    error_message = "Total keys (secrets + metadata + connection_info) should equal 72"




  }
}
