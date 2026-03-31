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

  systemd_services = flatten([
    for lxc_name, lxc in var.lxc_containers : [
      for svc_name, svc in lxc.systemd_services : {
        key      = "${lxc_name}-${svc_name}"
        lxc_name = lxc_name
        lxc_ip   = lxc.ip_address
        vmid     = lxc.vmid
        svc_name = svc_name
        content = templatefile("${path.module}/templates/lxc-systemd.service.tftpl", {
          description          = svc.description
          exec_start           = svc.exec_start
          working_dir          = svc.working_dir
          user                 = svc.user
          restart              = svc.restart
          restart_sec          = svc.restart_sec
          env_file             = svc.env_file
          env_vars             = svc.env_vars
          after                = svc.after
          wanted_by            = svc.wanted_by
          start_limit_burst    = svc.start_limit_burst
          start_limit_interval = svc.start_limit_interval
          syslog_identifier    = svc_name
        })
        deploy = lxc.deploy
      }
    ]
  ])

  systemd_services_map = { for svc in local.systemd_services : svc.key => svc }

  config_files = flatten([
    for lxc_name, lxc in var.lxc_containers : [
      for cfg_name, cfg in lxc.config_files : {
        key      = "${lxc_name}-${cfg_name}"
        lxc_name = lxc_name
        lxc_ip   = lxc.ip_address
        vmid     = lxc.vmid
        cfg_name = cfg_name
        path     = cfg.path
        content  = cfg.content
        perms    = cfg.permissions
        deploy   = lxc.deploy
      }
    ]
  ])

  config_files_map = { for cfg in local.config_files : cfg.key => cfg }

  docker_composes = {
    for lxc_name, lxc in var.lxc_containers : lxc_name => {
      lxc_name = lxc_name
      lxc_ip   = lxc.ip_address
      vmid     = lxc.vmid
      path     = lxc.docker_compose.path
      content  = lxc.docker_compose.content
      deploy   = lxc.deploy
    } if lxc.docker_compose != null
  }
}

check "deploy_requires_ssh_key" {
  assert {
    condition     = !var.deploy_lxc_configs || length(local.ssh_private_key) > 0
    error_message = "deploy_lxc_configs=true requires non-empty ssh_private_key content."
  }
}

resource "local_file" "systemd_services" {
  for_each = local.systemd_services_map

  content         = each.value.content
  filename        = "${path.root}/configs/lxc-${each.value.vmid}-${each.value.lxc_name}/${each.value.svc_name}.service"
  file_permission = "0644"
}

resource "local_sensitive_file" "config_files" {
  for_each = nonsensitive(local.config_files_map)

  content         = each.value.content
  filename        = "${path.root}/configs/lxc-${each.value.vmid}-${each.value.lxc_name}/${each.value.cfg_name}"
  file_permission = each.value.perms
}

resource "local_sensitive_file" "docker_compose" {
  for_each = nonsensitive(local.docker_composes)

  content         = each.value.content
  filename        = "${path.root}/configs/lxc-${each.value.vmid}-${each.value.lxc_name}/docker-compose.yml"
  file_permission = "0644"
}

resource "null_resource" "deploy_systemd_services" {
  for_each = var.deploy_lxc_configs ? { for k, v in local.systemd_services_map : k => v if v.deploy } : {}

  triggers = {
    service_hash = sha256(each.value.content)
  }

  provisioner "file" {
    content     = each.value.content
    destination = "/tmp/${each.value.svc_name}.service"

    connection {
      type        = "ssh"
      host        = each.value.lxc_ip
      user        = var.ssh_user
      private_key = local.ssh_private_key
      agent       = false
    }
  }

  provisioner "remote-exec" {
    inline = [
      "mv /tmp/${each.value.svc_name}.service /etc/systemd/system/",
      "systemctl daemon-reload",
      "systemctl enable ${each.value.svc_name}",
      "systemctl restart ${each.value.svc_name}"
    ]

    connection {
      type        = "ssh"
      host        = each.value.lxc_ip
      user        = var.ssh_user
      private_key = local.ssh_private_key
      agent       = false
    }
  }

  depends_on = [local_file.systemd_services]
}

# Health check: verify systemd services are active after deployment
resource "null_resource" "health_check_systemd" {
  for_each = var.enable_health_checks && var.deploy_lxc_configs ? { for k, v in local.systemd_services_map : k => v if v.deploy } : {}

  triggers = {
    # Re-run health check when service changes
    service_hash = sha256(each.value.content)
  }

  provisioner "remote-exec" {
    inline = [
      "sleep ${var.health_check_delay}",
      "echo 'Health check: ${each.value.svc_name} on ${each.value.lxc_name}'",
      "systemctl is-active ${each.value.svc_name} || (journalctl -u ${each.value.svc_name} -n 20 --no-pager && exit 1)"
    ]

    connection {
      type        = "ssh"
      host        = each.value.lxc_ip
      user        = var.ssh_user
      private_key = local.ssh_private_key
      agent       = false
    }
  }

  depends_on = [null_resource.deploy_systemd_services]
}

resource "null_resource" "deploy_config_files" {
  for_each = var.deploy_lxc_configs ? { for k, v in local.config_files_map : k => v if v.deploy } : {}

  triggers = {
    config_hash = sha256(each.value.content)
  }

  provisioner "file" {
    content     = each.value.content
    destination = "/tmp/${each.value.cfg_name}"

    connection {
      type        = "ssh"
      host        = each.value.lxc_ip
      user        = var.ssh_user
      private_key = local.ssh_private_key
      agent       = false
    }
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p $(dirname ${each.value.path})",
      "mv /tmp/${each.value.cfg_name} ${each.value.path}",
      "chmod ${each.value.perms} ${each.value.path}"
    ]

    connection {
      type        = "ssh"
      host        = each.value.lxc_ip
      user        = var.ssh_user
      private_key = local.ssh_private_key
      agent       = false
    }
  }

  depends_on = [local_sensitive_file.config_files]
}

resource "null_resource" "install_filebeat" {
  for_each = var.deploy_lxc_configs ? {
    for k, v in var.lxc_containers : k => v if v.setup_filebeat
  } : {}

  triggers = {
    script_hash = sha256(file("${path.module}/../../../scripts/install-filebeat.sh"))
  }

  provisioner "file" {
    source      = "${path.module}/../../../scripts/install-filebeat.sh"
    destination = "/tmp/install-filebeat.sh"

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
      "chmod +x /tmp/install-filebeat.sh",
      "sudo bash /tmp/install-filebeat.sh",
      "rm /tmp/install-filebeat.sh"
    ]

    connection {
      type        = "ssh"
      host        = each.value.ip_address
      user        = var.ssh_user
      private_key = local.ssh_private_key
      agent       = false
    }
  }

  depends_on = [null_resource.deploy_config_files]
}

# Cloud-init deployment for LXC containers
# Uses SSH to simulate cloud-init behavior since Proxmox LXC doesn't natively support cloud-init
locals {
  # Filter containers that have cloud_init configuration
  containers_with_cloudinit = {
    for name, lxc in var.lxc_containers : name => lxc
    if length(lxc.cloud_init.packages) > 0 ||
    length(lxc.cloud_init.write_files) > 0 ||
    length(lxc.cloud_init.runcmd) > 0
  }
}

# Render cloud-init configuration files locally
resource "local_file" "cloud_init_configs" {
  for_each = local.containers_with_cloudinit

  content = templatefile("${path.module}/templates/cloud-init-lxc.yaml.tftpl", {
    hostname    = each.value.hostname
    packages    = each.value.cloud_init.packages
    write_files = each.value.cloud_init.write_files
    runcmd      = each.value.cloud_init.runcmd
  })
  filename        = "${path.root}/configs/lxc-${each.value.vmid}-${each.value.hostname}/cloud-init.yaml"
  file_permission = "0644"
}

# Deploy cloud-init configuration via SSH and execute
resource "null_resource" "deploy_cloud_init" {
  for_each = var.deploy_lxc_configs ? local.containers_with_cloudinit : {}

  triggers = {
    config_hash = sha256(templatefile("${path.module}/templates/cloud-init-lxc.yaml.tftpl", {
      hostname    = each.value.hostname
      packages    = each.value.cloud_init.packages
      write_files = each.value.cloud_init.write_files
      runcmd      = each.value.cloud_init.runcmd
    }))
    host = each.value.ip_address
  }

  connection {
    type        = "ssh"
    host        = each.value.ip_address
    user        = var.ssh_user
    private_key = local.ssh_private_key
    agent       = false
    timeout     = "5m"
  }

  # Ensure cloud-init directories exist
  provisioner "remote-exec" {
    inline = [
      "mkdir -p /etc/cloud/cloud.cfg.d",
      "mkdir -p /var/lib/cloud",
    ]
  }

  # Upload cloud-init configuration
  provisioner "file" {
    content = templatefile("${path.module}/templates/cloud-init-lxc.yaml.tftpl", {
      hostname    = each.value.hostname
      packages    = each.value.cloud_init.packages
      write_files = each.value.cloud_init.write_files
      runcmd      = each.value.cloud_init.runcmd
    })
    destination = "/etc/cloud/cloud.cfg.d/99-terraform.cfg"
  }

  # Execute cloud-init (simulated)
  provisioner "remote-exec" {
    inline = flatten([
      # Check if already executed with same config
      "CURRENT_HASH=$(cat /var/lib/cloud/.terraform-init-hash 2>/dev/null || echo '')",
      "NEW_HASH='${sha256(templatefile("${path.module}/templates/cloud-init-lxc.yaml.tftpl", {
        hostname    = each.value.hostname
        packages    = each.value.cloud_init.packages
        write_files = each.value.cloud_init.write_files
        runcmd      = each.value.cloud_init.runcmd
      }))}'",
      "[ \"$CURRENT_HASH\" = \"$NEW_HASH\" ] && { echo 'Cloud-init already applied with same config'; exit 0; }",
      "",
      "echo 'Applying cloud-init for ${each.value.hostname}...'",
      "",
      # Install packages if specified
      length(each.value.cloud_init.packages) > 0 ? [
        "apt-get update -qq",
        "apt-get install -y -qq ${join(" ", each.value.cloud_init.packages)}",
      ] : [],
      "",
      # Write files if specified
      length(each.value.cloud_init.write_files) > 0 ? [
        for file in each.value.cloud_init.write_files : [
          "mkdir -p $(dirname ${file.path})",
          "cat > ${file.path} << 'EOF'",
          file.content,
          "EOF",
          "chmod ${file.permissions} ${file.path}",
          "chown ${file.owner} ${file.path}",
        ]
      ] : [],
      "",
      # Run commands if specified
      length(each.value.cloud_init.runcmd) > 0 ? [
        for cmd in each.value.cloud_init.runcmd : cmd
      ] : [],
      "",
      # Mark completion with hash for idempotency
      "echo '${sha256(templatefile("${path.module}/templates/cloud-init-lxc.yaml.tftpl", {
        hostname    = each.value.hostname
        packages    = each.value.cloud_init.packages
        write_files = each.value.cloud_init.write_files
        runcmd      = each.value.cloud_init.runcmd
      }))}' > /var/lib/cloud/.terraform-init-hash",
      "touch /var/lib/cloud/.terraform-init-done",
      "echo 'Cloud-init completed for ${each.value.hostname}'",
    ])
  }

  depends_on = [local_file.cloud_init_configs]
}
