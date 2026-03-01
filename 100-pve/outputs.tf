# =============================================================================
# OUTPUTS
# =============================================================================

output "nodes" {
  description = "List of Proxmox nodes"
  value       = data.proxmox_virtual_environment_nodes.nodes.names
}

output "container_ips" {
  description = "Container IP addresses"
  value = {
    for k, v in module.lxc : k => v.ip_address
  }
}

output "container_ids" {
  description = "Container VMIDs"
  value = {
    for k, v in module.lxc : k => v.vmid
  }
}

output "container_status" {
  description = "Container deployment status"
  value = {
    for k, v in module.lxc : k => {
      vmid    = v.vmid
      started = v.status.started
      node    = v.status.node
    }
  }
}

output "validation_summary" {
  description = "Configuration validation summary"
  value = {
    node_valid       = contains(data.proxmox_virtual_environment_nodes.nodes.names, local.node_name)
    containers_count = length(local.containers)
    vmid_range       = "${var.managed_vmid_range.min}-${var.managed_vmid_range.max}"
    network_cidr     = var.network_cidr
  }
}

output "vm_configs" {
  description = "VM configuration paths"
  value       = module.vm_config.vm_configs
}

output "lxc_configs" {
  description = "LXC configuration paths"
  value       = module.lxc_config.lxc_configs
  sensitive   = true
}

output "rendered_configs" {
  description = "Paths to rendered configuration files"
  value       = module.config_renderer.rendered_files
}

output "required_template_secrets_validation" {
  description = "Fail-fast validation for required 1Password secret keys consumed by rendered templates"
  value       = true

  precondition {
    condition = length(local.missing_required_template_secret_keys) == 0
    error_message = format(
      "Missing required 1Password secret keys for template rendering: %s",
      join(
        ", ",
        sort(nonsensitive(local.missing_required_template_secret_keys)),
      ),
    )
  }
}

output "host_inventory" {
  description = "Host inventory map (ip, ports, vmid) for consumption by app workspaces via remote_state"
  value       = module.hosts.hosts
}

output "service_urls" {
  description = "Derived service URLs for consumption by app workspaces via remote_state"
  value = {
    grafana_url = "https://grafana.jclee.me"
    n8n_url     = "https://mcphub.jclee.me"
  }
}
