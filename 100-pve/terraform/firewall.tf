# ──────────────────────────────────────────────────────────────────────────────
# Proxmox Firewall Rules — DISABLED (all traffic allowed)
# ──────────────────────────────────────────────────────────────────────────────
# WARNING: Firewall is currently disabled. All inbound/outbound traffic is allowed.
# To re-enable: Set enabled = true and input_policy/output_policy = "DROP"

locals {
  # ── Guest registry ─────────────────────────────────────────────────────────
  firewall_guests = {
    elk         = "container"
    "jclee-dev" = "vm"
    youtube     = "vm"
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
    rdp                 = "RDP"
    realtime            = "Realtime"
    server              = "Server"
    ui                  = "UI"
    web                 = "Web UI"
  }

  # ── Per-host overrides ─────────────────────────────────────────────────────
  firewall_overrides = {
    elk = {
      exclude = ["es_transport", "logstash_api", "logstash_http"]
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

module "firewall_container" {
  source = "../../modules/proxmox/firewall"

  node_name    = var.node_name
  targets      = local.container_firewall
  egress_rules = local._egress_common
  target_kind  = "container"
}

module "firewall_vm" {
  source = "../../modules/proxmox/firewall"

  node_name    = var.node_name
  targets      = local.vm_firewall
  egress_rules = local._egress_common
  target_kind  = "vm"
}

moved {
  from = proxmox_virtual_environment_firewall_rules.container
  to   = module.firewall_container.proxmox_virtual_environment_firewall_rules.this
}

moved {
  from = proxmox_virtual_environment_firewall_rules.vm
  to   = module.firewall_vm.proxmox_virtual_environment_firewall_rules.this
}

moved {
  from = proxmox_virtual_environment_firewall_options.container
  to   = module.firewall_container.proxmox_virtual_environment_firewall_options.this
}

moved {
  from = proxmox_virtual_environment_firewall_options.vm
  to   = module.firewall_vm.proxmox_virtual_environment_firewall_options.this
}

# Import commands (run manually, not as HCL import blocks which break terraform test):
# terraform import 'proxmox_virtual_environment_firewall_rules.vm["youtube"]' vm/pve3/220
