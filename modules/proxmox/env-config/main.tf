variable "hosts" {
  description = "Infrastructure host inventory"
  type = map(object({
    vmid  = number
    ip    = string
    roles = list(string)
    ports = map(number)
  }))
}

variable "network" {
  description = "Network configuration"
  type = object({
    subnet  = string
    gateway = string
    domain  = string
  })
  default = {
    subnet  = "192.168.50.0/24"
    gateway = "192.168.50.1"
    domain  = "jclee.me"
  }
}

locals {
  services = {
    elasticsearch_url = "http://${var.hosts.elk.ip}:${var.hosts.elk.ports.elasticsearch}"
    kibana_url        = "http://${var.hosts.elk.ip}:${var.hosts.elk.ports.kibana}"
    logstash_beats    = "${var.hosts.elk.ip}:${var.hosts.elk.ports.logstash_beat}"
    prometheus_url    = "http://${var.hosts.grafana.ip}:${var.hosts.grafana.ports.prometheus}"
    grafana_url       = "http://${var.hosts.grafana.ip}:${var.hosts.grafana.ports.grafana}"
    mcphub_url        = "http://${var.hosts.mcphub.ip}:${var.hosts.mcphub.ports.web}"
    n8n_url           = "http://${var.hosts.mcphub.ip}:${var.hosts.mcphub.ports.n8n}"
    supabase_url      = "http://${var.hosts.supabase.ip}:${var.hosts.supabase.ports.api}"
    archon_url        = "http://${var.hosts.archon.ip}:${var.hosts.archon.ports.ui}"
  }

  prometheus_node_targets = [
    for name, host in var.hosts : "${host.ip}:9100"
    if !contains(host.roles, "hypervisor")
  ]

  mcp_server_urls = {
    for port_name, port in var.hosts.mcphub.ports :
    port_name => "http://${var.hosts.mcphub.ip}:${port}/sse"
  }

  traefik_backends = {
    for name, host in var.hosts : name => {
      ip    = host.ip
      ports = host.ports
    }
    if length(host.ports) > 0
  }

  # Infrastructure nodes for Prometheus (exclude hypervisor)
  infrastructure_nodes = [
    for name, host in var.hosts : {
      name = name
      ip   = host.ip
      vmid = host.vmid
    }
    if !contains(host.roles, "hypervisor")
  ]

  # Template rendering data
  template_vars = {
    elk_ip               = var.hosts.elk.ip
    elk_ports            = var.hosts.elk.ports
    elasticsearch_port   = var.hosts.elk.ports.elasticsearch
    kibana_port          = var.hosts.elk.ports.kibana
    logstash_beats_port  = var.hosts.elk.ports.logstash_beat
    logstash_syslog_port = lookup(var.hosts.elk.ports, "logstash_syslog", 5000)
    traefik_ip           = var.hosts.traefik.ip
    traefik_ports        = var.hosts.traefik.ports
    grafana_ip           = var.hosts.grafana.ip
    grafana_ports        = var.hosts.grafana.ports
    glitchtip_ip         = var.hosts.glitchtip.ip
    glitchtip_port       = var.hosts.glitchtip.ports.web
    mcphub_ip            = var.hosts.mcphub.ip
    mcphub_port          = var.hosts.mcphub.ports.web
    n8n_ip               = var.hosts.mcphub.ip
    n8n_port             = var.hosts.mcphub.ports.n8n
    domain               = var.network.domain
    infrastructure_nodes = local.infrastructure_nodes
    # ELK docker-compose variables
    elk_version                 = "8.12.0"
    es_heap                     = "2g"
    logstash_heap               = "512m"
    elasticsearch_index_pattern = "logs-%%{+YYYY.MM.dd}"
    # Synology NAS
    synology_ip    = var.hosts.synology.ip
    synology_ports = var.hosts.synology.ports
    # Supabase (107)
    supabase_ip     = var.hosts.supabase.ip
    supabase_port   = var.hosts.supabase.ports.api
    supabase_studio = var.hosts.supabase.ports.studio
    # Archon (108)
    archon_ip     = var.hosts.archon.ip
    archon_port   = var.hosts.archon.ports.ui
    archon_server = var.hosts.archon.ports.server
    archon_mcp    = var.hosts.archon.ports.mcp
    # Vault (runs on mcphub VM as Docker container)
    vault_ip   = var.hosts.mcphub.ip
    vault_port = var.hosts.mcphub.ports.vault
    # Grafana SLA dashboard
    prometheus_datasource_uid = "prometheus"
    sla_target_percentage     = "99.9"
  }
}

output "services" {
  description = "Derived service URLs from host inventory"
  value       = local.services
}

output "prometheus_node_targets" {
  description = "Node exporter endpoints for Prometheus scrape config"
  value       = local.prometheus_node_targets
}

output "mcp_server_urls" {
  description = "MCP server SSE endpoints"
  value       = local.mcp_server_urls
}

output "traefik_backends" {
  description = "Backend service definitions for Traefik dynamic config"
  value       = local.traefik_backends
}

output "elasticsearch_url" {
  value = local.services.elasticsearch_url
}

output "kibana_url" {
  value = local.services.kibana_url
}

output "logstash_beats" {
  value = local.services.logstash_beats
}

output "prometheus_url" {
  value = local.services.prometheus_url
}

output "grafana_url" {
  value = local.services.grafana_url
}

output "mcphub_url" {
  value = local.services.mcphub_url
}

output "n8n_url" {
  value = local.services.n8n_url
}
