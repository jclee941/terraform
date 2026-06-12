terraform {
  required_version = ">= 1.7, < 2.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.94"
    }
  }
}

resource "proxmox_virtual_environment_firewall_rules" "this" {
  for_each = var.targets

  node_name    = var.node_name
  container_id = var.target_kind == "container" ? each.value.vmid : null
  vm_id        = var.target_kind == "vm" ? each.value.vmid : null

  dynamic "rule" {
    for_each = each.value.rules
    content {
      type    = "in"
      action  = "ACCEPT"
      proto   = rule.value.proto
      dport   = rule.value.dport
      comment = "${each.key}: ${rule.value.comment}"
      log     = "nolog"
    }
  }

  dynamic "rule" {
    for_each = var.egress_rules
    content {
      type    = "out"
      action  = "ACCEPT"
      proto   = rule.value.proto
      dport   = rule.value.dport
      dest    = rule.value.dest
      comment = "${each.key}: Egress ${rule.value.comment}"
      log     = "nolog"
    }
  }
}

resource "proxmox_virtual_environment_firewall_options" "this" {
  for_each = var.targets

  node_name    = var.node_name
  container_id = var.target_kind == "container" ? each.value.vmid : null
  vm_id        = var.target_kind == "vm" ? each.value.vmid : null

  enabled       = false
  input_policy  = "ACCEPT"
  output_policy = "ACCEPT"
}
