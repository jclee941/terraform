output "vm_configs" {
  description = "Generated VM configuration paths"
  value = {
    for name, vm in var.vms : name => {
      vmid       = vm.vmid
      hostname   = vm.hostname
      ip_address = vm.ip_address
      cloud_init = local_file.cloud_init[name].filename
      systemd_services = [
        for svc_name, svc in vm.systemd_services : {
          name = svc_name
          path = local_file.systemd_services["${name}-${svc_name}"].filename
        }
      ]
    }
  }
}

output "cloud_init_paths" {
  description = "Map of VM name to cloud-init file path"
  value       = { for name, file in local_file.cloud_init : name => file.filename }
}
