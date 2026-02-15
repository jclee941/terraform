output "config_files" {
  description = "Config files map compatible with lxc-config/vm-config input format"
  value = {
    "vault-agent-config" = {
      path    = "/etc/vault-agent/${var.service_name}.hcl"
      content = local.vault_agent_config
    }
    "vault-agent-service" = {
      path    = "/etc/systemd/system/vault-agent-${var.service_name}.service"
      content = local.vault_agent_service
    }
  }
  sensitive = true
}

output "role_id" {
  description = "AppRole role ID for external provisioning"
  value       = vault_approle_auth_backend_role.service.role_id
  sensitive   = true
}

output "secret_id" {
  description = "AppRole secret ID for external provisioning"
  value       = vault_approle_auth_backend_role_secret_id.service.secret_id
  sensitive   = true
}
