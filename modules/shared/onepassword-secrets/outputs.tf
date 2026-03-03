# Flattened secret values for template injection.
# Keys are prefixed by service name to avoid collisions.
# Drop-in replacement for modules/shared/vault-secrets — identical output interface.
#
# Access pattern: section_map["secrets"].field_map["<key>"].value
# Each 1Password item must have a section named "secrets" with matching field labels.
# All lookups use try() to default to "" — allows terraform test with mock_provider.
#
# Secrets (sensitive=true): API keys, passwords, tokens — 37 keys.
# Metadata (sensitive=false): Usernames, URLs, emails, account/zone IDs — 11 keys.
output "secrets" {
  description = "Flat map of all homelab secrets for template_vars merge (37 keys)"
  sensitive   = true
  value = {
    # Grafana
    grafana_admin_password        = try(data.onepassword_item.grafana.section_map["secrets"].field_map["admin_password"].value, "")
    grafana_service_account_token = try(data.onepassword_item.grafana.section_map["secrets"].field_map["service_account_token"].value, "")

    # GlitchTip
    glitchtip_django_secret_key = try(data.onepassword_item.glitchtip.section_map["secrets"].field_map["django_secret_key"].value, "")
    glitchtip_postgres_password = try(data.onepassword_item.glitchtip.section_map["secrets"].field_map["postgres_password"].value, "")
    glitchtip_redis_password    = try(data.onepassword_item.glitchtip.section_map["secrets"].field_map["redis_password"].value, "")
    glitchtip_api_token         = try(data.onepassword_item.glitchtip.section_map["secrets"].field_map["api_token"].value, "")

    # Proxmox
    proxmox_api_token_value = try(data.onepassword_item.proxmox.section_map["secrets"].field_map["api_token_value"].value, "")
    proxmox_ssh_private_key = try(data.onepassword_item.proxmox.section_map["secrets"].field_map["ssh_private_key"].value, "")

    # GitHub
    github_personal_access_token = try(data.onepassword_item.github.section_map["secrets"].field_map["personal_access_token"].value, "")

    # Exa (web search)
    exa_api_key = try(data.onepassword_item.exa.section_map["secrets"].field_map["api_key"].value, "")

    # Supabase
    supabase_service_key        = try(data.onepassword_item.supabase.section_map["secrets"].field_map["service_key"].value, "")
    supabase_anon_key           = try(data.onepassword_item.supabase.section_map["secrets"].field_map["anon_key"].value, "")
    supabase_service_role_key   = try(data.onepassword_item.supabase.section_map["secrets"].field_map["service_role_key"].value, "")
    supabase_db_password        = try(data.onepassword_item.supabase.section_map["secrets"].field_map["db_password"].value, "")
    supabase_jwt_secret         = try(data.onepassword_item.supabase.section_map["secrets"].field_map["jwt_secret"].value, "")
    supabase_dashboard_password = try(data.onepassword_item.supabase.section_map["secrets"].field_map["dashboard_password"].value, "")

    # Archon
    archon_anthropic_key = try(data.onepassword_item.archon.section_map["secrets"].field_map["anthropic_api_key"].value, "")
    openai_api_key       = try(data.onepassword_item.archon.section_map["secrets"].field_map["openai_api_key"].value, "")

    # Cloudflare
    cloudflare_api_key         = try(data.onepassword_item.cloudflare.section_map["secrets"].field_map["api_key"].value, "")
    cloudflare_tunnel_token    = try(data.onepassword_item.cloudflare.section_map["secrets"].field_map["tunnel_token"].value, "")
    google_oauth_client_id     = try(data.onepassword_item.cloudflare.section_map["secrets"].field_map["google_oauth_client_id"].value, "")
    google_oauth_client_secret = try(data.onepassword_item.cloudflare.section_map["secrets"].field_map["google_oauth_client_secret"].value, "")

    # n8n
    n8n_api_key             = try(data.onepassword_item.n8n.section_map["secrets"].field_map["api_key"].value, "")
    n8n_github_token        = try(data.onepassword_item.n8n.section_map["secrets"].field_map["github_token"].value, "")
    n8n_glitchtip_api_token = try(data.onepassword_item.n8n.section_map["secrets"].field_map["glitchtip_api_token"].value, "")

    # MCPHub (MCPHub-specific secrets only)
    mcphub_proxmox_token_name       = try(data.onepassword_item.mcphub.section_map["secrets"].field_map["proxmox_token_name"].value, "")
    mcphub_proxmox_token_value      = try(data.onepassword_item.mcphub.section_map["secrets"].field_map["proxmox_token_value"].value, "")
    mcphub_admin_password           = try(data.onepassword_item.mcphub.section_map["secrets"].field_map["admin_password"].value, "")
    mcphub_n8n_mcp_api_key          = try(data.onepassword_item.mcphub.section_map["secrets"].field_map["n8n_mcp_api_key"].value, "")
    mcphub_op_service_account_token = try(data.onepassword_item.mcphub.section_map["secrets"].field_map["op_service_account_token"].value, "")

    # Slack (dedicated 1Password item — separated from mcphub)
    slack_mcp_xoxp_token = try(data.onepassword_item.slack.section_map["secrets"].field_map["slack_mcp_xoxp_token"].value, "")
    slack_mcp_xoxb_token = try(data.onepassword_item.slack.section_map["secrets"].field_map["slack_mcp_xoxb_token"].value, "")
    slack_bot_token      = try(data.onepassword_item.slack.section_map["secrets"].field_map["slack_mcp_xoxb_token"].value, "") # alias: consumers expect slack_bot_token
    slack_webhook_url    = try(data.onepassword_item.slack.section_map["secrets"].field_map["webhook_url"].value, "")

    # ELK / Elasticsearch
    elk_elastic_password = try(data.onepassword_item.elk.section_map["secrets"].field_map["elastic_password"].value, "")
    elk_kibana_password  = try(data.onepassword_item.elk.section_map["secrets"].field_map["kibana_password"].value, "")

    # PBS (Proxmox Backup Server)
    pbs_password = try(data.onepassword_item.pbs.section_map["secrets"].field_map["password"].value, "")
  }
}

output "metadata" {
  description = "Non-secret configuration metadata: usernames, URLs, IDs (11 keys)"
  sensitive   = false
  value = {
    # Supabase
    supabase_url                = try(data.onepassword_item.supabase.section_map["secrets"].field_map["url"].value, "")
    supabase_dashboard_username = try(data.onepassword_item.supabase.section_map["secrets"].field_map["dashboard_username"].value, "")

    # Cloudflare
    cloudflare_email      = try(data.onepassword_item.cloudflare.section_map["secrets"].field_map["email"].value, "")
    cloudflare_account_id = try(data.onepassword_item.cloudflare.section_map["secrets"].field_map["account_id"].value, "")
    cloudflare_zone_id    = try(data.onepassword_item.cloudflare.section_map["secrets"].field_map["zone_id"].value, "")

    # n8n
    n8n_webhook_url           = try(data.onepassword_item.n8n.section_map["secrets"].field_map["webhook_url"].value, "")
    n8n_glitchtip_webhook_url = try(data.onepassword_item.n8n.section_map["secrets"].field_map["glitchtip_webhook_url"].value, "")

    # PBS (Proxmox Backup Server)
    pbs_server      = try(data.onepassword_item.pbs.section_map["secrets"].field_map["server"].value, "")
    pbs_datastore   = try(data.onepassword_item.pbs.section_map["secrets"].field_map["datastore"].value, "")
    pbs_username    = try(data.onepassword_item.pbs.section_map["secrets"].field_map["username"].value, "")
    pbs_fingerprint = try(data.onepassword_item.pbs.section_map["secrets"].field_map["fingerprint"].value, "")
  }
}
