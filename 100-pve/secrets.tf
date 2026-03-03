# =============================================================================
# 1PASSWORD SECRETS
# =============================================================================

module "onepassword_secrets" {
  source     = "../modules/shared/onepassword-secrets"
  vault_name = var.onepassword_vault_name
}

# =============================================================================
# CONFIG RENDERER - Centralized Config Generation
# =============================================================================

module "config_renderer" {
  source = "../modules/proxmox/config-renderer"

  template_vars = merge(
    module.onepassword_secrets.secrets,
    module.onepassword_secrets.metadata,
    {
      hosts                = module.hosts.hosts
      domain               = "jclee.me"
      network_cidr         = var.network_cidr
      github_org           = var.github_org
      infrastructure_nodes = local.infrastructure_nodes

      elk_version = "8.17.0"

      glitchtip_version          = "v6.0.5"
      glitchtip_postgres_version = "15.16-alpine"
      glitchtip_redis_version    = "7.4.7-alpine"
      mcphub_version             = "0.12.5"

      es_heap                     = "3g"
      logstash_heap               = "1g"
      logstash_dlq_size           = "1024mb"
      elasticsearch_index_pattern = "logs-%%{[service]}-%%{+YYYY.MM.dd}"
      ilm_delete_after            = "30d"
      ilm_policy_name             = "homelab-logs-30d"
      ilm_critical_delete_after   = "90d"
      ilm_ephemeral_delete_after  = "7d"

      prometheus_datasource_uid = "prometheus"
      sla_target_percentage     = "99.9"

      mcp_catalog_json           = jsonencode(local.mcp_catalog)
      mcp_hub_servers_json       = jsonencode(local.mcp_hub_servers)
      mcp_hub_stdio_json         = jsonencode(local.mcp_hub_stdio_servers)
      mcp_hub_sse_json           = jsonencode(local.mcp_hub_sse_servers)
      mcp_hub_external_sse_json  = jsonencode(local.mcp_hub_external_sse_servers)
      mcp_hub_http_json          = jsonencode(local.mcp_hub_http_servers)
      mcp_hub_external_http_json = jsonencode(local.mcp_hub_external_http_servers)
      mcp_host                   = local.mcp_catalog.mcp_host
      proxmox_host               = local.proxmox_host
      proxmox_port               = local.proxmox_port
      proxmox_ssl_mode           = local.proxmox_ssl_mode
      homelab_tunnel_token       = local.effective_homelab_tunnel_token
    }
  )
  output_dir = "${path.module}/configs/rendered"

  template_files = merge(
    local.root_templates,
    local.service_templates,
  )
}
