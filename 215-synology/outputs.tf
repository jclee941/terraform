# -----------------------------------------------------------------------------
# Network
# -----------------------------------------------------------------------------

output "network_info" {
  description = "Synology NAS network configuration"
  value = {
    server_name   = data.synology_core_network.this.server_name
    dns_primary   = data.synology_core_network.this.dns_primary
    dns_secondary = data.synology_core_network.this.dns_secondary
    gateway       = data.synology_core_network.this.gateway
  }
}

# -----------------------------------------------------------------------------
# Packages
# -----------------------------------------------------------------------------

output "container_manager_installed" {
  description = "Whether ContainerManager package is installed"
  value       = var.enable_container_manager_package ? length(synology_core_package.container_manager) > 0 : true
}

output "gitlab_project_enabled" {
  description = "Whether GitLab container project management is enabled"
  value       = var.enable_gitlab_project
}

output "gitlab_endpoints" {
  description = "GitLab endpoint details when container project is enabled"
  value = var.enable_gitlab_project ? {
    external_url = var.gitlab_external_url
    http_port    = var.gitlab_http_port
    ssh_port     = var.gitlab_ssh_port
  } : null
}

# -----------------------------------------------------------------------------
# Container Registry
# -----------------------------------------------------------------------------

output "gitlab_registry_enabled" {
  description = "Whether GitLab Container Registry is enabled"
  value       = var.enable_gitlab_registry
}

output "gitlab_registry_endpoint" {
  description = "GitLab Container Registry endpoint when enabled"
  value       = var.enable_gitlab_registry ? var.gitlab_registry_external_url : null
}

# -----------------------------------------------------------------------------
# GitLab Runner
# -----------------------------------------------------------------------------

output "gitlab_runner_enabled" {
  description = "Whether GitLab Runner is deployed"
  value       = var.enable_gitlab_runner
}
