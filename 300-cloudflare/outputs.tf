output "secrets_store_id" {
  description = "Cloudflare Secrets Store ID used by this configuration"
  value       = var.cloudflare_secrets_store_id
}

output "managed_github_repos" {
  description = "GitHub repositories receiving managed Actions secrets"
  value       = local.github_repo_names
}

output "managed_vault_paths" {
  description = "Vault paths managed by this configuration"
  value       = local.vault_paths
}

output "total_secrets_count" {
  description = "Total number of secrets in inventory"
  value       = local.total_secrets_count
}
