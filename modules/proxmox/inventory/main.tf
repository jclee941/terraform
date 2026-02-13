# Proxmox Infrastructure Host Inventory
#
# DEPRECATED: This module is a legacy duplicate of the authoritative SSoT
# at terraform/envs/prod/hosts.tf. Do NOT add new hosts here.
# Use module.hosts (from envs/prod/hosts.tf) as the canonical source.
# This module is retained only for backward compatibility with existing
# references to module.inventory.* outputs.
#
# TODO: Migrate all consumers to module.hosts and remove this module.

locals {
  network = {
    subnet  = "192.168.50.0/24"
    gateway = "192.168.50.1"
    domain  = "jclee.me"
  }

  hosts = {
    pve = {
      vmid  = 100
      ip    = "192.168.50.100"
      roles = ["hypervisor"]
      ports = {}
    }

    # Archived: terraform (103), minio_cache (109), n8n (110), mcpdog (111), github_runner (113)
    # Active (standalone TF workspaces): supabase (107), archon (108)

    runner = {
      vmid  = 101
      ip    = "192.168.50.101"
      roles = ["ci", "runner"]
      ports = {}
    }

    traefik = {
      vmid  = 102
      ip    = "192.168.50.102"
      roles = ["proxy", "ingress"]
      ports = {
        http    = 80
        https   = 443
        traefik = 8080
      }
    }

    grafana = {
      vmid  = 104
      ip    = "192.168.50.104"
      roles = ["observability", "monitoring"]
      ports = {
        grafana    = 3000
        prometheus = 9090
      }
    }

    elk = {
      vmid  = 105
      ip    = "192.168.50.105"
      roles = ["logging", "elasticsearch", "kibana"]
      ports = {
        elasticsearch = 9200
        es_transport  = 9300
        kibana        = 5601
        logstash_beat = 5044
        logstash_tcp  = 5000
        logstash_api  = 9600
      }
    }

    glitchtip = {
      vmid  = 106
      ip    = "192.168.50.106"
      roles = ["error-tracking", "monitoring"]
      ports = {
        web      = 8000
        postgres = 5432
        redis    = 6379
      }
    }

    mcphub = {
      vmid  = 112
      ip    = "192.168.50.112"
      roles = ["mcp-hub", "ai", "mcp", "gateway", "automation"]
      ports = {
        web        = 3000
        proxmox    = 8055
        playwright = 8056
        n8n        = 5678
      }
    }

    sandbox = {
      vmid  = 220
      ip    = "192.168.50.220"
      roles = ["development", "sandbox"]
      ports = {}
    }

  }

  services = {
    elasticsearch_url  = "http://${local.hosts.elk.ip}:${local.hosts.elk.ports.elasticsearch}"
    kibana_url         = "http://${local.hosts.elk.ip}:${local.hosts.elk.ports.kibana}"
    logstash_beats_url = "${local.hosts.elk.ip}:${local.hosts.elk.ports.logstash_beat}"
    prometheus_url     = "http://${local.hosts.grafana.ip}:${local.hosts.grafana.ports.prometheus}"
    grafana_url        = "http://${local.hosts.grafana.ip}:${local.hosts.grafana.ports.grafana}"
    glitchtip_url      = "http://${local.hosts.glitchtip.ip}:${local.hosts.glitchtip.ports.web}"
    mcphub_url         = "http://${local.hosts.mcphub.ip}:${local.hosts.mcphub.ports.web}"
  }

  prometheus_targets = [
    for name, host in local.hosts : "${host.ip}:9100"
    if contains(host.roles, "monitoring") == false && host.vmid != 100
  ]

  traefik_backends = {
    for name, host in local.hosts : name => {
      ip    = host.ip
      ports = host.ports
    }
    if length(host.ports) > 0
  }
}
