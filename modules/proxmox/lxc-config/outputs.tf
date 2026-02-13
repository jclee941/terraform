output "lxc_configs" {
  description = "Generated LXC configuration paths"
  value = {
    for name, lxc in var.lxc_containers : name => {
      vmid       = lxc.vmid
      hostname   = lxc.hostname
      ip_address = lxc.ip_address
      systemd_services = [
        for svc_name, svc in lxc.systemd_services : {
          name = svc_name
          path = local_file.systemd_services["${name}-${svc_name}"].filename
        }
      ]
      config_files = [
        for cfg_name, cfg in lxc.config_files : {
          name = cfg_name
          path = local_sensitive_file.config_files["${name}-${cfg_name}"].filename
        }
      ]
      docker_compose = lxc.docker_compose != null ? local_sensitive_file.docker_compose[name].filename : null
    }
  }
}

output "service_count" {
  description = "Total number of systemd services managed"
  value       = length(local.systemd_services_map)
}
