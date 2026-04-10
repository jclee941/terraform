# ──────────────────────────────────────────────────────────────────────────────
# Proxmox Firewall Rules — DISABLED (all traffic allowed)
# ──────────────────────────────────────────────────────────────────────────────
# WARNING: Firewall is currently disabled. All inbound/outbound traffic is allowed.
# To re-enable: Set enabled = true and input_policy/output_policy = "DROP"

locals {
  # ── Guest registry ─────────────────────────────────────────────────────────
    cliproxy = "container"
    runner   = "container"
    traefik  = "container"
    traefik         = "container"
    coredns         = "container"
    elk             = "container"
    supabase        = "container"
    archon          = "container"
    n8n             = "container"
    mcphub          = "vm"
    "jclee-dev"     = "vm"
    youtube         = "vm"
  }

  # ── Port labels ────────────────────────────────────────────────────────────
  port_labels = {
    api                 = "API"
    db                  = "PostgreSQL"
    dns                 = "DNS"
    elasticsearch       = "Elasticsearch"
    health              = "Health check"
    http                = "HTTP ingress"
    https               = "HTTPS ingress"
    kibana              = "Kibana"
    logstash_beat       = "Logstash beats input"
    logstash_prometheus = "Logstash Prometheus exporter"
    logstash_tcp        = "Logstash TCP input"
    mcp                 = "MCP"
    n8n                 = "n8n"
    prometheus          = "Prometheus"
    rdp                 = "RDP"
    realtime            = "Realtime"
    server              = "Server"
    studio              = "Supabase Studio"
    traefik             = "Traefik API"
    ui                  = "UI"
    web                 = "Web UI"
  }

  # ── Per-host overrides ─────────────────────────────────────────────────────
  firewall_overrides = {
    coredns = {
      dual_proto = ["dns"]
    }
    elk = {
      exclude = ["es_transport", "logstash_api", "logstash_http"]
    }
    supabase = {
      exclude = ["inbucket"]
    }
    n8n = {
      exclude = ["postgres"]
    }
    mcphub = {
      exclude = ["proxmox", "playwright", "op_connect"]
      extra = [
        { dport = "8055:8079", proto = "tcp", comment = "MCP server ports" },
      ]
    }
    "jclee-dev" = {
      exclude = ["opencode", "ssh"]
    }
  }

  # ── Egress filtering ──────────────────────────────────────────────────────
  _egress_common = [
    { dest = "192.168.50.0/24", proto = "tcp", dport = null, comment = "Local subnet (TCP)" },
    { dest = "192.168.50.0/24", proto = "udp", dport = null, comment = "Local subnet (UDP)" },
    { dest = null, proto = "tcp", dport = "53", comment = "DNS" },
    { dest = null, proto = "udp", dport = "53", comment = "DNS (UDP)" },
    { dest = null, proto = "tcp", dport = "80", comment = "HTTP outbound" },
    { dest = null, proto = "tcp", dport = "443", comment = "HTTPS outbound" },
    { dest = null, proto = "udp", dport = "123", comment = "NTP" },
  ]

  # ── Generated rules (do not edit below) ────────────────────────────────────

  _firewall_rules = {
    for name, guest_type in local.firewall_guests : name => {
      vmid = module.hosts.hosts[name].vmid
      rules = concat(
        # SSH auto-injected for all guests
        [{ dport = "22", proto = "tcp", comment = "SSH" }],
        # TCP rules derived from hosts.tf ports map
        [
          for port_name, port_num in module.hosts.hosts[name].ports : {
            dport   = tostring(port_num)
            proto   = "tcp"
            comment = lookup(local.port_labels, port_name, replace(port_name, "_", " "))
          }
          if !contains(try(local.firewall_overrides[name].exclude, []), port_name)
          && port_name != "ssh" # SSH already auto-injected above
        ],
        # UDP duplicates for dual-protocol ports (e.g., DNS)
        [
          for port_name in try(local.firewall_overrides[name].dual_proto, []) : {
            dport   = tostring(module.hosts.hosts[name].ports[port_name])
            proto   = "udp"
            comment = "${lookup(local.port_labels, port_name, port_name)} (UDP)"
          }
        ],
        # Extra rules: port ranges or special cases not in hosts.tf
        try(local.firewall_overrides[name].extra, []),
      )
    }
  }

  container_firewall = {
    for name, fw in local._firewall_rules : name => fw
    if local.firewall_guests[name] == "container"
  }

  vm_firewall = {
    for name, fw in local._firewall_rules : name => fw
    if local.firewall_guests[name] == "vm"
  }
}

# NOTE: Firewall rules are defined but NOT applied since firewall_options disables the firewall
# To re-enable firewall, change enabled = true and policies to "DROP"

resource "proxmox_virtual_environment_firewall_rules" "container" {
  for_each = local.container_firewall

  node_name    = var.node_name
  container_id = each.value.vmid

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
    for_each = local._egress_common
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

resource "proxmox_virtual_environment_firewall_rules" "vm" {
  for_each = local.vm_firewall

  node_name = var.node_name
  vm_id     = each.value.vmid

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
    for_each = local._egress_common
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

# ──────────────────────────────────────────────────────────────────────────────
# Firewall Options — FIREWALL DISABLED (all traffic allowed)
# ──────────────────────────────────────────────────────────────────────────────
# enabled: false — Firewall is completely disabled
# input_policy: ACCEPT — All inbound traffic allowed
# output_policy: ACCEPT — All outbound traffic allowed

resource "proxmox_virtual_environment_firewall_options" "container" {
  for_each = local.container_firewall

  node_name    = var.node_name
  container_id = each.value.vmid

  enabled       = false
  input_policy  = "ACCEPT"
  output_policy = "ACCEPT"
}

resource "proxmox_virtual_environment_firewall_options" "vm" {
  for_each = local.vm_firewall

  node_name = var.node_name
  vm_id     = each.value.vmid

  enabled       = false
  input_policy  = "ACCEPT"
  output_policy = "ACCEPT"
}

# Import commands (run manually, not as HCL import blocks which break terraform test):
# terraform import 'proxmox_virtual_environment_firewall_rules.vm["youtube"]' vm/pve3/220
