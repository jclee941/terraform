# =============================================================================
# 1PASSWORD SECRETS
# =============================================================================

module "onepassword_secrets" {
  source          = "../../modules/shared/onepassword-secrets"
  vault_name      = var.onepassword_vault_name
  enable_pbs      = var.enable_pbs
  enable_registry = var.enable_registry
  enable_synology = var.enable_synology
  enable_youtube  = var.enable_youtube
}

# =============================================================================
# CONFIG RENDERER - Centralized Config Generation
# =============================================================================

module "config_renderer" {
  source = "../../modules/proxmox/config-renderer"

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

      es_heap                     = "3g"
      logstash_heap               = "1g"
      logstash_dlq_size           = "1024mb"
      elasticsearch_index_pattern = "logs-%%{[service]}-%%{+YYYY.MM.dd}"
      ilm_delete_after            = "30d"
      ilm_policy_name             = "homelab-logs-30d"
      ilm_critical_delete_after   = "90d"
      ilm_ephemeral_delete_after  = "7d"

      proxmox_host         = local.proxmox_host
      proxmox_port         = local.proxmox_port
      proxmox_ssl_mode     = local.proxmox_ssl_mode
      homelab_tunnel_token = local.effective_homelab_tunnel_token
    }
  )
  output_dir = "${path.module}/configs/rendered"

  template_files = local.service_templates
}
