# ──────────────────────────────────────────────────────────────────────────────
# Proxmox Firewall Rules — data-driven per-guest inbound port restrictions
# ──────────────────────────────────────────────────────────────────────────────
# Port definitions derived from hosts.tf SSoT with per-host overrides.
# SSH (port 22/tcp) auto-injected for all managed guests.
# Default policy: DROP all inbound except explicitly allowed ports.
#
# To add a new host:   add entry to firewall_guests map below.
# To add a new port:   add to hosts.tf ports map (auto-exposed in firewall).
# To exclude a port:   add to firewall_overrides[host].exclude list.

locals {
  # ── Guest registry ─────────────────────────────────────────────────────────
  # Guest type determines firewall resource (container_id vs vm_id).
  # Add new hosts here when provisioning — port rules auto-derived from hosts.tf.
  firewall_guests = {
    runner      = "container"
    traefik     = "container"
    coredns     = "container"
    grafana     = "container"
    elk         = "container"
    glitchtip   = "container"
    supabase    = "container"
    archon      = "container"
    ollama      = "vm"
    mcphub      = "vm"
    "jclee-dev" = "vm"
    youtube     = "vm"
  }

  # ── Port labels ────────────────────────────────────────────────────────────
  # Human-readable labels for Proxmox firewall UI comments.
  # Fallback: port key name with underscores replaced by spaces.
  port_labels = {
    api                 = "API"
    db                  = "PostgreSQL"
    dns                 = "DNS"
    elasticsearch       = "Elasticsearch"
    grafana             = "Grafana UI"
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
  # Only hosts with non-default behavior need entries here.
  #   exclude:    port names from hosts.tf to NOT expose (internal-only services)
  #   dual_proto: port names needing both TCP and UDP rules
  #   extra:      additional rules not derivable from hosts.tf (port ranges, etc.)
  firewall_overrides = {
    coredns = {
      dual_proto = ["dns"]
    }
    elk = {
      exclude = ["es_transport", "logstash_api", "logstash_http"]
    }
    glitchtip = {
      exclude = ["postgres", "redis"]
    }
    supabase = {
      exclude = ["inbucket"]
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
}

# Import commands (run manually, not as HCL import blocks which break terraform test):
# terraform import 'proxmox_virtual_environment_firewall_rules.vm["ollama"]' vm/pve3/109
# terraform import 'proxmox_virtual_environment_firewall_rules.vm["youtube"]' vm/pve3/220
