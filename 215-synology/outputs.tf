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

output "proxmox_monitor_status" {
  description = "Synology Container Manager project status for the Proxmox Telegram monitor"
  value       = var.enable_proxmox_monitor ? synology_container_project.proxmox_monitor["this"].status : "disabled"
}

# -----------------------------------------------------------------------------
# MailPlus
# -----------------------------------------------------------------------------

output "mailplus_catch_all" {
  description = "Configured MailPlus catch-all target for the primary domain"
  value = var.enable_mailplus_catch_all ? {
    domain_id = var.mailplus_domain_id
    user      = var.mailplus_catch_all_user
  } : null
}


# -----------------------------------------------------------------------------
# Portainer
# -----------------------------------------------------------------------------

output "portainer_enabled" {
  description = "Whether Portainer container project is enabled"
  value       = var.enable_portainer
}

output "portainer_endpoints" {
  description = "Portainer endpoint details when container project is enabled"
  value = var.enable_portainer ? {
    https_url = "https://192.168.50.215:${var.portainer_https_port}"
    edge_port = var.portainer_edge_port
  } : null
}
