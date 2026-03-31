output "secrets_store_id" {
  description = "Cloudflare Secrets Store ID used by this configuration"
  value       = var.cloudflare_secrets_store_id
}

output "total_secrets_count" {
  description = "Total number of secrets in inventory"
  value       = local.total_secrets_count
}
