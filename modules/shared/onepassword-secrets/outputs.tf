locals {
  proxmox_api_token_value = try(data.onepassword_item.this["proxmox"].section_map["Credentials"].field_map["api_token_value"].value, try(data.onepassword_item.this["proxmox"].credential, ""))
  proxmox_endpoint        = try(data.onepassword_item.this["proxmox"].section_map["Credentials"].field_map["endpoint"].value, "")
  proxmox_ssh_private_key = try(data.onepassword_item.this["proxmox"].section_map["Keys"].field_map["private_key"].value, "")


  supabase_service_key        = try(data.onepassword_item.this["supabase"].section_map["Keys"].field_map["service_key"].value, "")
  supabase_anon_key           = try(data.onepassword_item.this["supabase"].section_map["Keys"].field_map["anon_key"].value, "")
  supabase_service_role_key   = try(data.onepassword_item.this["supabase"].section_map["Keys"].field_map["service_role_key"].value, try(data.onepassword_item.this["supabase"].section_map["Keys"].field_map["service_key"].value, ""))
  supabase_db_password        = try(data.onepassword_item.this["supabase"].section_map["Database"].field_map["db_password"].value, "")
  supabase_jwt_secret         = try(data.onepassword_item.this["supabase"].section_map["Keys"].field_map["jwt_secret"].value, "")
  supabase_dashboard_password = try(data.onepassword_item.this["supabase"].section_map["Dashboard"].field_map["password"].value, "")
  supabase_url                = try(data.onepassword_item.this["supabase"].section_map["Connection"].field_map["url"].value, try(data.onepassword_item.this["supabase"].section_map["Connection"].field_map["api_url"].value, ""))
  supabase_dashboard_username = try(data.onepassword_item.this["supabase"].section_map["Dashboard"].field_map["username"].value, "")

  archon_anthropic_key = try(data.onepassword_item.this["archon"].section_map["API Keys"].field_map["anthropic_api_key"].value, "")
  openai_api_key       = try(data.onepassword_item.this["archon"].section_map["API Keys"].field_map["openai_api_key"].value, "")

  cloudflare_api_key         = try(data.onepassword_item.this["cloudflare"].section_map["API Keys"].field_map["global_api_key"].value, try(data.onepassword_item.this["cloudflare"].section_map["API Keys"].field_map["api_key"].value, ""))
  cloudflare_api_token       = try(data.onepassword_item.this["cloudflare"].section_map["API Keys"].field_map["api_token"].value, try(data.onepassword_item.this["cloudflare"].section_map["API Keys"].field_map["api_key"].value, ""))
  cloudflare_tunnel_token    = try(data.onepassword_item.this["cloudflare"].section_map["API Keys"].field_map["tunnel_token"].value, "")
  google_oauth_client_id     = try(data.onepassword_item.this["cloudflare"].section_map["API Keys"].field_map["google_oauth_client_id"].value, "")
  google_oauth_client_secret = try(data.onepassword_item.this["cloudflare"].section_map["API Keys"].field_map["google_oauth_client_secret"].value, "")
  cloudflare_email           = try(data.onepassword_item.this["cloudflare"].section_map["Account"].field_map["email"].value, "")
  cloudflare_account_id      = try(data.onepassword_item.this["cloudflare"].section_map["Account"].field_map["account_id"].value, "")
  cloudflare_zone_id         = try(data.onepassword_item.this["cloudflare"].section_map["Account"].field_map["zone_id"].value, "")

  n8n_api_key           = try(data.onepassword_item.this["n8n"].section_map["API Keys"].field_map["api_key"].value, "")
  n8n_github_token      = try(data.onepassword_item.this["n8n"].section_map["API Keys"].field_map["github_token"].value, "")
  n8n_webhook_url       = try(data.onepassword_item.this["n8n"].section_map["Connection"].field_map["webhook_url"].value, "")
  n8n_postgres_password = try(data.onepassword_item.this["n8n"].section_map["Database"].field_map["postgres_password"].value, "")
  n8n_encryption_key    = try(data.onepassword_item.this["n8n"].section_map["Secrets"].field_map["encryption_key"].value, "")

  mcphub_proxmox_token_name       = try(data.onepassword_item.this["mcphub"].section_map["Credentials"].field_map["proxmox_token_name"].value, "")
  mcphub_proxmox_token_value      = try(data.onepassword_item.this["mcphub"].section_map["Credentials"].field_map["proxmox_token_value"].value, "")
  mcphub_admin_password           = try(data.onepassword_item.this["mcphub"].section_map["Credentials"].field_map["admin_password"].value, "")
  mcphub_n8n_mcp_api_key          = try(data.onepassword_item.this["mcphub"].section_map["Credentials"].field_map["n8n_mcp_api_key"].value, "")
  mcphub_op_service_account_token = try(data.onepassword_item.this["mcphub"].section_map["Credentials"].field_map["op_service_account_token"].value, "")
  mcphub_op_connect_token = try(
    data.onepassword_item.this["mcphub"].section_map["Credentials"].field_map["op_connect_token"].value,
    try(data.onepassword_item.this["mcphub"].section_map["Credentials"].field_map["op_service_account_token"].value, "")
  )

  slack_mcp_xoxp_token = try(data.onepassword_item.this["slack"].section_map["MCP Tokens"].field_map["xoxp_token"].value, "")
  slack_mcp_xoxb_token = try(data.onepassword_item.this["slack"].section_map["MCP Tokens"].field_map["xoxb_token"].value, try(data.onepassword_item.this["slack"].section_map["OpenCode Tokens"].field_map["bot_token"].value, ""))
  slack_bot_token      = try(data.onepassword_item.this["slack"].section_map["OpenCode Tokens"].field_map["bot_token"].value, "")
  slack_webhook_url    = try(data.onepassword_item.this["slack"].section_map["Connection"].field_map["webhook_url"].value, "")

  elk_elastic_password = try(data.onepassword_item.this["elk"].section_map["Passwords"].field_map["elastic_password"].value, "")
  elk_kibana_password  = try(data.onepassword_item.this["elk"].section_map["Passwords"].field_map["kibana_password"].value, "")

  traefik_htpasswd_hash = try(data.onepassword_item.this["traefik"].section_map["Credentials"].field_map["htpasswd_hash"].value, "")

  pbs_password    = var.enable_pbs ? try(data.onepassword_item.this["pbs"].section_map["Login"].field_map["password"].value, try(data.onepassword_item.this["pbs"].password, "")) : ""
  pbs_server      = var.enable_pbs ? try(data.onepassword_item.this["pbs"].section_map["Connection"].field_map["server"].value, "") : ""
  pbs_datastore   = var.enable_pbs ? try(data.onepassword_item.this["pbs"].section_map["Connection"].field_map["datastore"].value, "") : ""
  pbs_username    = var.enable_pbs ? try(data.onepassword_item.this["pbs"].section_map["Login"].field_map["username"].value, "") : ""
  pbs_fingerprint = var.enable_pbs ? try(data.onepassword_item.this["pbs"].section_map["Connection"].field_map["fingerprint"].value, "") : ""

  synology_user     = var.enable_synology ? try(data.onepassword_item.this["synology"].section_map["Credentials"].field_map["user"].value, try(data.onepassword_item.this["synology"].username, "")) : ""
  synology_password = var.enable_synology ? try(data.onepassword_item.this["synology"].section_map["Credentials"].field_map["password"].value, try(data.onepassword_item.this["synology"].password, "")) : ""

  youtube_google_client_id     = var.enable_youtube ? try(data.onepassword_item.this["youtube"].section_map["OAuth"].field_map["google_client_id"].value, "") : ""
  youtube_google_client_secret = var.enable_youtube ? try(data.onepassword_item.this["youtube"].section_map["OAuth"].field_map["google_client_secret"].value, "") : ""
  youtube_google_refresh_token = var.enable_youtube ? try(data.onepassword_item.this["youtube"].section_map["OAuth"].field_map["google_refresh_token"].value, "") : ""
  youtube_google_project_id    = var.enable_youtube ? try(data.onepassword_item.this["youtube"].section_map["Connection"].field_map["google_project_id"].value, "") : ""
  youtube_channel_id           = var.enable_youtube ? try(data.onepassword_item.this["youtube"].section_map["Connection"].field_map["channel_id"].value, "") : ""

  gcp_credentials = var.enable_gcp ? try(data.onepassword_item.this["gcp"].section_map["Credentials"].field_map["credentials"].value, "") : ""
  gcp_project_id  = var.enable_gcp ? try(data.onepassword_item.this["gcp"].section_map["Connection"].field_map["project_id"].value, "") : ""
  gcp_region      = var.enable_gcp ? try(data.onepassword_item.this["gcp"].section_map["Connection"].field_map["region"].value, "") : ""

  # AI & Media Integrations for n8n
  telegram_bot_token = try(data.onepassword_item.this["telegram"].credential, "")

}

output "secrets" {
  description = "Flat map of all homelab secrets for template_vars merge (37 keys)"
  sensitive   = true
  value = {
    # Proxmox
    proxmox_api_token_value = local.proxmox_api_token_value
    proxmox_ssh_private_key = local.proxmox_ssh_private_key

    # GitHub

    # Supabase
    supabase_service_key        = local.supabase_service_key
    supabase_anon_key           = local.supabase_anon_key
    supabase_service_role_key   = local.supabase_service_role_key
    supabase_db_password        = local.supabase_db_password
    supabase_jwt_secret         = local.supabase_jwt_secret
    supabase_dashboard_password = local.supabase_dashboard_password

    # Archon
    archon_anthropic_key = local.archon_anthropic_key
    openai_api_key       = local.openai_api_key

    # Cloudflare
    cloudflare_api_key         = local.cloudflare_api_key
    cloudflare_api_token       = local.cloudflare_api_token
    cloudflare_tunnel_token    = local.cloudflare_tunnel_token
    google_oauth_client_id     = local.google_oauth_client_id
    google_oauth_client_secret = local.google_oauth_client_secret

    # n8n
    n8n_api_key           = local.n8n_api_key
    n8n_github_token      = local.n8n_github_token
    n8n_postgres_password = local.n8n_postgres_password
    n8n_encryption_key    = local.n8n_encryption_key

    # MCPHub (MCPHub-specific secrets only)
    mcphub_proxmox_token_name       = local.mcphub_proxmox_token_name
    mcphub_proxmox_token_value      = local.mcphub_proxmox_token_value
    mcphub_admin_password           = local.mcphub_admin_password
    mcphub_n8n_mcp_api_key          = local.mcphub_n8n_mcp_api_key
    mcphub_op_service_account_token = local.mcphub_op_service_account_token
    mcphub_op_connect_token         = local.mcphub_op_connect_token

    # Slack (dedicated 1Password item — separated from mcphub)
    slack_mcp_xoxp_token = local.slack_mcp_xoxp_token
    slack_mcp_xoxb_token = local.slack_mcp_xoxb_token
    slack_bot_token      = local.slack_bot_token
    slack_webhook_url    = local.slack_webhook_url

    # ELK / Elasticsearch
    elk_elastic_password = local.elk_elastic_password
    elk_kibana_password  = local.elk_kibana_password

    # PBS (Proxmox Backup Server)
    pbs_password = local.pbs_password

    # Traefik
    traefik_htpasswd_hash = local.traefik_htpasswd_hash

    # Synology
    synology_user     = local.synology_user
    synology_password = local.synology_password

    # YouTube (Google OAuth)
    youtube_google_client_id     = local.youtube_google_client_id
    youtube_google_client_secret = local.youtube_google_client_secret
    youtube_google_refresh_token = local.youtube_google_refresh_token

    # GCP (Google Cloud Platform)
    gcp_credentials = local.gcp_credentials

    # AI & Media Integrations for n8n
    telegram_bot_token = local.telegram_bot_token

  }
}

output "metadata" {
  description = "Non-secret configuration metadata: usernames, URLs, IDs (14 keys)"
  sensitive   = false
  value = {
    # Supabase
    supabase_url                = local.supabase_url
    supabase_dashboard_username = local.supabase_dashboard_username

    # Cloudflare
    cloudflare_email      = local.cloudflare_email
    cloudflare_account_id = local.cloudflare_account_id
    cloudflare_zone_id    = local.cloudflare_zone_id

    # n8n
    n8n_webhook_url = local.n8n_webhook_url

    # PBS (Proxmox Backup Server)
    pbs_server      = local.pbs_server
    pbs_datastore   = local.pbs_datastore
    pbs_username    = local.pbs_username
    pbs_fingerprint = local.pbs_fingerprint

    # YouTube
    youtube_google_project_id = local.youtube_google_project_id
    youtube_channel_id        = local.youtube_channel_id

    # GCP (Google Cloud Platform)
    gcp_project_id = local.gcp_project_id
    gcp_region     = local.gcp_region
  }
}

output "connection_info" {
  description = "Non-secret connection details and routing metadata (16 keys)"
  sensitive   = false
  value = {
    proxmox_endpoint            = local.proxmox_endpoint
    slack_webhook_url           = local.slack_webhook_url
    supabase_url                = local.supabase_url
    supabase_dashboard_username = local.supabase_dashboard_username
    cloudflare_email            = local.cloudflare_email
    cloudflare_account_id       = local.cloudflare_account_id
    cloudflare_zone_id          = local.cloudflare_zone_id
    n8n_webhook_url             = local.n8n_webhook_url
    pbs_server                  = local.pbs_server
    pbs_datastore               = local.pbs_datastore
    pbs_username                = local.pbs_username
    pbs_fingerprint             = local.pbs_fingerprint
    youtube_google_project_id   = local.youtube_google_project_id
    youtube_channel_id          = local.youtube_channel_id
    gcp_project_id              = local.gcp_project_id
    gcp_region                  = local.gcp_region
  }
}
