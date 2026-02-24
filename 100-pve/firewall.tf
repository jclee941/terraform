# ──────────────────────────────────────────────────────────────────────────────
# Proxmox Firewall Rules — per-container/VM inbound port restrictions
# ──────────────────────────────────────────────────────────────────────────────
# Security boundary enforcement for all TF-managed LXC/VM hosts.
# Port definitions sourced from module.hosts inventory (hosts.tf).
# Default policy: DROP all inbound except explicitly allowed ports.

locals {
  container_firewall = {
    runner = {
      vmid = module.hosts.hosts.runner.vmid
      rules = [
        { dport = "22", proto = "tcp", comment = "SSH" },
      ]
    }
    traefik = {
      vmid = module.hosts.hosts.traefik.vmid
      rules = [
        { dport = "22", proto = "tcp", comment = "SSH" },
        { dport = "80", proto = "tcp", comment = "HTTP ingress" },
        { dport = "443", proto = "tcp", comment = "HTTPS ingress" },
        { dport = "8080", proto = "tcp", comment = "Traefik API" },
      ]
    }
    coredns = {
      vmid = module.hosts.hosts.coredns.vmid
      rules = [
        { dport = "22", proto = "tcp", comment = "SSH" },
        { dport = "53", proto = "tcp", comment = "DNS (TCP)" },
        { dport = "53", proto = "udp", comment = "DNS (UDP)" },
        { dport = "8080", proto = "tcp", comment = "Health check" },
      ]
    }
    grafana = {
      vmid = module.hosts.hosts.grafana.vmid
      rules = [
        { dport = "22", proto = "tcp", comment = "SSH" },
        { dport = "3000", proto = "tcp", comment = "Grafana UI" },
        { dport = "9090", proto = "tcp", comment = "Prometheus" },
      ]
    }
    elk = {
      vmid = module.hosts.hosts.elk.vmid
      rules = [
        { dport = "22", proto = "tcp", comment = "SSH" },
        { dport = "9200", proto = "tcp", comment = "Elasticsearch" },
        { dport = "5601", proto = "tcp", comment = "Kibana" },
        { dport = "5044", proto = "tcp", comment = "Logstash beats input" },
        { dport = "5000", proto = "tcp", comment = "Logstash TCP input" },
        { dport = "9198", proto = "tcp", comment = "Logstash Prometheus exporter" },
      ]
    }
    glitchtip = {
      vmid = module.hosts.hosts.glitchtip.vmid
      rules = [
        { dport = "22", proto = "tcp", comment = "SSH" },
        { dport = "8000", proto = "tcp", comment = "GlitchTip web" },
      ]
    }
    supabase = {
      vmid = module.hosts.hosts.supabase.vmid
      rules = [
        { dport = "22", proto = "tcp", comment = "SSH" },
        { dport = "3000", proto = "tcp", comment = "Supabase Studio" },
        { dport = "8000", proto = "tcp", comment = "Supabase API" },
        { dport = "5432", proto = "tcp", comment = "PostgreSQL" },
        { dport = "4000", proto = "tcp", comment = "Supabase Realtime" },
      ]
    }
    archon = {
      vmid = module.hosts.hosts.archon.vmid
      rules = [
        { dport = "22", proto = "tcp", comment = "SSH" },
        { dport = "3737", proto = "tcp", comment = "Archon UI" },
        { dport = "8181", proto = "tcp", comment = "Archon server" },
        { dport = "8051", proto = "tcp", comment = "Archon MCP" },
      ]
    }
  }

  vm_firewall = {
    # NOTE: jclee (VMID 80) excluded — Proxmox provider requires vm_id >= 100
    # Firewall rules for VMID 80 must be managed via PVE GUI or CLI
    mcphub = {
      vmid = module.hosts.hosts.mcphub.vmid
      rules = [
        { dport = "22", proto = "tcp", comment = "SSH" },
        { dport = "3000", proto = "tcp", comment = "MCPHub web" },
        { dport = "5678", proto = "tcp", comment = "n8n" },
        { dport = "8055:8079", proto = "tcp", comment = "MCP server ports" },
      ]
    }
  }
}

resource "proxmox_virtual_environment_firewall_rules" "container" {
  for_each = local.container_firewall

  node_name    = "pve"
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

  node_name = "pve"
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
