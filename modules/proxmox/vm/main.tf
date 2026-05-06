terraform {
  required_version = ">= 1.7, < 2.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.94"
    }
  }
}

data "proxmox_virtual_environment_nodes" "nodes" {}

resource "proxmox_virtual_environment_vm" "this" {
  name        = var.hostname
  description = var.description
  node_name   = var.node_name
  vm_id       = var.vmid
  bios        = var.bios
  machine     = var.machine
  on_boot     = var.on_boot

  dynamic "efi_disk" {
    for_each = var.bios == "ovmf" ? [1] : []
    content {
      datastore_id      = var.datastore_id
      type              = "4m"
      pre_enrolled_keys = true
    }
  }

  dynamic "tpm_state" {
    for_each = var.bios == "ovmf" ? [1] : []
    content {
      datastore_id = var.datastore_id
      version      = "v2.0"
    }
  }

  clone {
    vm_id = var.clone_template_id
    full  = true
  }

  agent {
    enabled = true
  }

  cpu {
    cores = var.cores
    type  = var.cpu_type
  }

  vga {
    type = "std"
  }

  memory {
    dedicated = var.memory
    floating  = var.balloon_min
  }

  disk {
    datastore_id = var.datastore_id
    interface    = var.disk_interface
    size         = var.disk_size
    iothread     = true
    ssd          = var.ssd_emulation
    discard      = var.disk_discard
    aio          = var.disk_aio
  }

  network_device {
    bridge = "vmbr0"
  }

  dynamic "hostpci" {
    for_each = var.hostpci_devices
    content {
      device  = hostpci.value.device
      mapping = hostpci.value.mapping
      id      = hostpci.value.id
      pcie    = hostpci.value.pcie
    }
  }

  initialization {
    datastore_id      = var.cloud_init_datastore_id
    user_data_file_id = var.cloud_init_file_id

    ip_config {
      ipv4 {
        address = "${var.ip_address}/24"
        gateway = var.network_gateway
      }
    }

    dns {
      servers = var.dns_servers
    }
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    precondition {
      condition     = contains(data.proxmox_virtual_environment_nodes.nodes.names, var.node_name)
      error_message = <<-EOT
        Node '${var.node_name}' not found in Proxmox cluster.
        Available nodes: ${join(", ", data.proxmox_virtual_environment_nodes.nodes.names)}
      EOT
    }

    precondition {
      condition     = var.vmid >= var.managed_vmid_min && var.vmid <= var.managed_vmid_max
      error_message = <<-EOT
        VM '${var.hostname}' VMID ${var.vmid} is outside managed range.
        Allowed: ${var.managed_vmid_min}-${var.managed_vmid_max}
      EOT
    }

    precondition {
      condition     = var.memory >= 512 && var.memory % 256 == 0
      error_message = <<-EOT
        VM '${var.hostname}' memory ${var.memory}MB invalid.
        Requirements: >= 512MB and divisible by 256
      EOT
    }

    ignore_changes = [
      clone,
      network_device[0].mac_address,
      network_device[0].disconnected,
      agent,
      operating_system,
      disk[0].datastore_id,
      efi_disk,
      initialization,
    ]

    prevent_destroy = true
  }
}
