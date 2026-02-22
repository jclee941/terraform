terraform {
  required_version = ">= 1.7, < 2.0"

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
  ssh_private_key = trimspace(replace(replace(var.ssh_private_key, "\r\n", "\n"), "\\n", "\n"))

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

  vm_write_files = flatten([
    for vm_name, vm in var.vms : [
      for idx, wf in try(vm.cloud_init.write_files, []) : {
        key         = "${vm_name}-${idx}"
        vm_name     = vm_name
        vm_ip       = vm.ip_address
        path        = wf.path
        content     = wf.content
        permissions = wf.permissions
        owner       = wf.owner
        owner_user  = split(":", wf.owner)[0]
        owner_group = length(split(":", wf.owner)) > 1 ? split(":", wf.owner)[1] : split(":", wf.owner)[0]
        deploy      = vm.deploy
      }
    ]
  ])

  vm_write_files_map = { for wf in local.vm_write_files : wf.key => wf }
}

check "deploy_requires_ssh_key" {
  assert {
    condition     = !var.deploy_vm_configs || length(local.ssh_private_key) > 0
    error_message = "deploy_vm_configs=true requires non-empty ssh_private_key content."
  }
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
      type        = "ssh"
      host        = each.value.vm_ip
      user        = var.ssh_user
      private_key = local.ssh_private_key
      agent       = false
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
      type        = "ssh"
      host        = each.value.vm_ip
      user        = var.ssh_user
      private_key = local.ssh_private_key
      agent       = false
    }
  }

  depends_on = [local_file.systemd_services]
}

resource "null_resource" "deploy_vm_write_files" {
  for_each = var.deploy_vm_configs ? { for k, v in local.vm_write_files_map : k => v if v.deploy } : {}

  triggers = {
    content_hash = sha256(each.value.content)
    path         = each.value.path
    permissions  = each.value.permissions
    owner        = each.value.owner
  }

  provisioner "file" {
    content     = each.value.content
    destination = "/tmp/${each.value.key}.tmp"

    connection {
      type        = "ssh"
      host        = each.value.vm_ip
      user        = var.ssh_user
      private_key = local.ssh_private_key
      agent       = false
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo install -D -m ${each.value.permissions} -o ${each.value.owner_user} -g ${each.value.owner_group} /tmp/${each.value.key}.tmp ${each.value.path}",
      "rm -f /tmp/${each.value.key}.tmp"
    ]

    connection {
      type        = "ssh"
      host        = each.value.vm_ip
      user        = var.ssh_user
      private_key = local.ssh_private_key
      agent       = false
    }
  }
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
      type        = "ssh"
      host        = each.value.vm_ip
      user        = var.ssh_user
      private_key = local.ssh_private_key
      agent       = false
    }
  }

  depends_on = [
    null_resource.deploy_systemd_services,
    null_resource.deploy_vm_write_files,
  ]
}

resource "null_resource" "install_filebeat" {
  for_each = var.deploy_vm_configs ? {
    for k, v in var.vms : k => v if v.setup_filebeat
  } : {}

  triggers = {
    script_hash = sha256(file("${path.module}/../../../scripts/setup-filebeat.sh"))
  }

  provisioner "file" {
    source      = "${path.module}/../../../scripts/setup-filebeat.sh"
    destination = "/tmp/setup-filebeat.sh"

    connection {
      type        = "ssh"
      host        = each.value.ip_address
      user        = var.ssh_user
      private_key = local.ssh_private_key
      agent       = false
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/setup-filebeat.sh",
      "sudo bash /tmp/setup-filebeat.sh",
      "rm /tmp/setup-filebeat.sh"
    ]

    connection {
      type        = "ssh"
      host        = each.value.ip_address
      user        = var.ssh_user
      private_key = local.ssh_private_key
      agent       = false
    }
  }

  depends_on = [null_resource.deploy_vm_write_files]
}
