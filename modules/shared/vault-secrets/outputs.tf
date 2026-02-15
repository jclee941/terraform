# Flattened secret values for template injection.
# Keys are prefixed by service name to avoid collisions.
output "secrets" {
  description = "Flat map of all homelab secrets for template_vars merge"
  sensitive   = true
  value = {
    # Grafana
    grafana_admin_password        = data.vault_kv_secret_v2.grafana.data["admin_password"]
    grafana_service_account_token = data.vault_kv_secret_v2.grafana.data["service_account_token"]

    # GlitchTip (try() defaults allow plan to succeed before Vault keys are populated)
    glitchtip_django_secret_key = try(data.vault_kv_secret_v2.glitchtip.data["django_secret_key"], "")
    glitchtip_postgres_password = try(data.vault_kv_secret_v2.glitchtip.data["postgres_password"], "")
    glitchtip_redis_password    = try(data.vault_kv_secret_v2.glitchtip.data["redis_password"], "")
    glitchtip_api_token         = try(data.vault_kv_secret_v2.glitchtip.data["api_token"], "")

    # Proxmox
    proxmox_api_token_value = data.vault_kv_secret_v2.proxmox.data["api_token_value"]

    # GitHub
    github_personal_access_token = data.vault_kv_secret_v2.github.data["personal_access_token"]

    # Exa (web search)
    exa_api_key = data.vault_kv_secret_v2.exa.data["api_key"]

    # Splunk
    splunk_username = data.vault_kv_secret_v2.splunk.data["username"]
    splunk_host     = data.vault_kv_secret_v2.splunk.data["host"]
    splunk_port     = data.vault_kv_secret_v2.splunk.data["port"]

    # Supabase (try() defaults allow plan to succeed before Vault keys are populated)
    supabase_url                = try(data.vault_kv_secret_v2.supabase.data["url"], "")
    supabase_service_key        = try(data.vault_kv_secret_v2.supabase.data["service_key"], "")
    supabase_anon_key           = try(data.vault_kv_secret_v2.supabase.data["anon_key"], "")
    supabase_service_role_key   = try(data.vault_kv_secret_v2.supabase.data["service_role_key"], "")
    supabase_db_password        = try(data.vault_kv_secret_v2.supabase.data["db_password"], "")
    supabase_jwt_secret         = try(data.vault_kv_secret_v2.supabase.data["jwt_secret"], "")
    supabase_dashboard_username = try(data.vault_kv_secret_v2.supabase.data["dashboard_username"], "")
    supabase_dashboard_password = try(data.vault_kv_secret_v2.supabase.data["dashboard_password"], "")

    # Archon (try() defaults allow plan to succeed before Vault keys are populated)
    archon_anthropic_key = try(data.vault_kv_secret_v2.archon.data["anthropic_api_key"], "")
    openai_api_key       = try(data.vault_kv_secret_v2.archon.data["openai_api_key"], "")

    # Cloudflare (try() defaults allow plan to succeed before Vault keys are populated)
    cloudflare_api_key    = try(data.vault_kv_secret_v2.cloudflare.data["api_key"], "")
    cloudflare_email      = try(data.vault_kv_secret_v2.cloudflare.data["email"], "")
    cloudflare_account_id = try(data.vault_kv_secret_v2.cloudflare.data["account_id"], "")
    cloudflare_zone_id    = try(data.vault_kv_secret_v2.cloudflare.data["zone_id"], "")

    # n8n (try() defaults allow plan to succeed before Vault keys are populated)
    n8n_api_key             = try(data.vault_kv_secret_v2.n8n.data["api_key"], "")
    n8n_github_token        = try(data.vault_kv_secret_v2.n8n.data["github_token"], "")
    n8n_glitchtip_api_token = try(data.vault_kv_secret_v2.n8n.data["glitchtip_api_token"], "")

    # MCPHub (try() defaults allow plan to succeed before Vault keys are populated)
    mcphub_proxmox_token_name  = try(data.vault_kv_secret_v2.mcphub.data["proxmox_token_name"], "")
    mcphub_proxmox_token_value = try(data.vault_kv_secret_v2.mcphub.data["proxmox_token_value"], "")
  }
}
