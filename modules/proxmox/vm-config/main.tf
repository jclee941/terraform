terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

locals {
  cloud_init_configs = {
    for name, vm in var.vms : name => templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
      hostname    = vm.hostname
      packages    = vm.cloud_init.packages
      runcmd      = vm.cloud_init.runcmd
      write_files = vm.cloud_init.write_files
    })
  }

  systemd_services = flatten([
    for vm_name, vm in var.vms : [
      for svc_name, svc in vm.systemd_services : {
        key      = "${vm_name}-${svc_name}"
        vm_name  = vm_name
        vm_ip    = vm.ip_address
        svc_name = svc_name
        content = templatefile("${path.module}/templates/systemd.service.tftpl", {
          description       = svc.description
          exec_start        = svc.exec_start
          working_dir       = svc.working_dir
          user              = svc.user
          restart           = svc.restart
          env_vars          = svc.env_vars
          after             = svc.after
          wanted_by         = svc.wanted_by
          syslog_identifier = svc_name
        })
        deploy = vm.deploy
      }
    ]
  ])

  systemd_services_map = { for svc in local.systemd_services : svc.key => svc }
}

resource "local_file" "cloud_init" {
  for_each = local.cloud_init_configs

  content         = each.value
  filename        = "${path.root}/configs/vm-${var.vms[each.key].vmid}-${each.key}/cloud-init.yaml"
  file_permission = "0644"
}

resource "local_file" "systemd_services" {
  for_each = local.systemd_services_map

  content         = each.value.content
  filename        = "${path.root}/configs/vm-${var.vms[each.value.vm_name].vmid}-${each.value.vm_name}/${each.value.svc_name}.service"
  file_permission = "0644"
}

resource "null_resource" "deploy_systemd_services" {
  for_each = var.deploy_vm_configs ? { for k, v in local.systemd_services_map : k => v if v.deploy } : {}

  triggers = {
    service_hash = sha256(each.value.content)
  }

  provisioner "file" {
    content     = each.value.content
    destination = "/tmp/${each.value.svc_name}.service"

    connection {
      type = "ssh"
      host = each.value.vm_ip
      user = var.ssh_user
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/${each.value.svc_name}.service /etc/systemd/system/",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable ${each.value.svc_name}",
      "sudo systemctl restart ${each.value.svc_name}"
    ]

    connection {
      type = "ssh"
      host = each.value.vm_ip
      user = var.ssh_user
    }
  }

  depends_on = [local_file.systemd_services]
}

# Health check: verify systemd services are active after deployment
resource "null_resource" "health_check_systemd" {
  for_each = var.enable_health_checks && var.deploy_vm_configs ? { for k, v in local.systemd_services_map : k => v if v.deploy } : {}

  triggers = {
    # Re-run health check when service changes
    service_hash = sha256(each.value.content)
  }

  provisioner "remote-exec" {
    inline = [
      "sleep ${var.health_check_delay}",
      "echo 'Health check: ${each.value.svc_name} on ${each.value.vm_name}'",
      "sudo systemctl is-active ${each.value.svc_name} || (sudo journalctl -u ${each.value.svc_name} -n 20 --no-pager && exit 1)"
    ]

    connection {
      type = "ssh"
      host = each.value.vm_ip
      user = var.ssh_user
    }
  }

  depends_on = [null_resource.deploy_systemd_services]
}
