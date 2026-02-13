# Flattened secret values for template injection.
# Keys are prefixed by service name to avoid collisions.
output "secrets" {
  description = "Flat map of all homelab secrets for template_vars merge"
  sensitive   = true
  value = {
    # Grafana
    grafana_admin_password        = data.vault_kv_secret_v2.grafana.data["admin_password"]
    grafana_service_account_token = data.vault_kv_secret_v2.grafana.data["service_account_token"]

    # GlitchTip
    glitchtip_django_secret_key = data.vault_kv_secret_v2.glitchtip.data["django_secret_key"]
    glitchtip_postgres_password = data.vault_kv_secret_v2.glitchtip.data["postgres_password"]
    glitchtip_redis_password    = data.vault_kv_secret_v2.glitchtip.data["redis_password"]
    glitchtip_api_token         = data.vault_kv_secret_v2.glitchtip.data["api_token"]

    # Proxmox
    proxmox_api_token_value = data.vault_kv_secret_v2.proxmox.data["api_token_value"]

    # GitHub
    github_personal_access_token = data.vault_kv_secret_v2.github.data["personal_access_token"]

    # Exa (web search)
    exa_api_key = data.vault_kv_secret_v2.exa.data["api_key"]

    # Splunk
    splunk_username = data.vault_kv_secret_v2.splunk.data["username"]
  }
}
