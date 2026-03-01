# ──────────────────────────────────────────────────────────────────────────────
# Service Registry — SSoT for all known log-producing services
# ──────────────────────────────────────────────────────────────────────────────

locals {
  # Service key must match the `service` field set by Logstash (logstash.conf.tftpl).
  # Tier determines ILM retention: critical=90d, standard=30d, ephemeral=7d.
  log_services = {
    archon             = { name = "Archon", tier = "critical" }
    auth               = { name = "Auth", tier = "standard" }
    cloudflare-workers = { name = "Cloudflare Workers", tier = "standard" }
    docker             = { name = "Docker", tier = "standard" }
    elk                = { name = "ELK", tier = "critical" }
    github-runner      = { name = "GitHub Runner", tier = "ephemeral" }
    glitchtip          = { name = "GlitchTip", tier = "standard" }
    grafana            = { name = "Grafana", tier = "critical" }
    mcphub             = { name = "MCPHub", tier = "standard" }
    opencode           = { name = "OpenCode", tier = "standard" }
    pve                = { name = "PVE", tier = "critical" }
    supabase           = { name = "Supabase", tier = "critical" }
    synology           = { name = "Synology", tier = "standard" }
    system             = { name = "System", tier = "standard" }
    youtube            = { name = "YouTube", tier = "ephemeral" }
  }

  # Derive index patterns from registry for index template assignment
  critical_patterns  = [for k, v in local.log_services : "logs-${k}-*" if v.tier == "critical"]
  ephemeral_patterns = [for k, v in local.log_services : "logs-${k}-*" if v.tier == "ephemeral"]
}

# ──────────────────────────────────────────────────────────────────────────────
# ILM Policies — tiered retention
# ──────────────────────────────────────────────────────────────────────────────

resource "elasticstack_elasticsearch_index_lifecycle" "homelab_logs_30d" {
  name = "homelab-logs-30d"

  hot {
    set_priority {
      priority = 100
    }
  }

  delete {
    min_age = "30d"
    delete {}
  }
}

resource "elasticstack_elasticsearch_index_lifecycle" "homelab_logs_critical_90d" {
  name = "homelab-logs-critical-90d"

  hot {
    set_priority {
      priority = 100
    }
  }

  delete {
    min_age = "90d"
    delete {}
  }
}

resource "elasticstack_elasticsearch_index_lifecycle" "homelab_logs_ephemeral_7d" {
  name = "homelab-logs-ephemeral-7d"

  hot {
    set_priority {
      priority = 100
    }
  }

  delete {
    min_age = "7d"
    delete {}
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# Index Templates — tier-based ILM assignment
# ──────────────────────────────────────────────────────────────────────────────

# Standard tier: catch-all for remaining services (30d retention, lowest priority)
resource "elasticstack_elasticsearch_index_template" "logs" {
  name           = "logs-template"
  index_patterns = ["logs-*"]
  priority       = 200

  template {
    settings = jsonencode({
      number_of_replicas     = 0
      number_of_shards       = 1
      "index.lifecycle.name" = elasticstack_elasticsearch_index_lifecycle.homelab_logs_30d.name
    })
  }
}

# Critical tier: core infrastructure services (90d retention)
resource "elasticstack_elasticsearch_index_template" "logs_critical" {
  name           = "logs-critical"
  index_patterns = local.critical_patterns
  priority       = 300

  template {
    settings = jsonencode({
      number_of_replicas     = 0
      number_of_shards       = 1
      "index.lifecycle.name" = elasticstack_elasticsearch_index_lifecycle.homelab_logs_critical_90d.name
    })
  }
}

# Ephemeral tier: debug, unknown, and high-volume ephemeral sources (7d retention)
resource "elasticstack_elasticsearch_index_template" "logs_ephemeral" {
  name           = "logs-ephemeral"
  index_patterns = local.ephemeral_patterns
  priority       = 250

  template {
    settings = jsonencode({
      number_of_replicas     = 0
      number_of_shards       = 1
      "index.lifecycle.name" = elasticstack_elasticsearch_index_lifecycle.homelab_logs_ephemeral_7d.name
    })
  }
}

# Cloudflare Workers: dedicated template for CF Worker traces (30d retention)
resource "elasticstack_elasticsearch_index_template" "logs_cloudflare_workers" {
  name           = "logs-cloudflare-workers"
  index_patterns = ["logs-cloudflare-workers-*"]
  priority       = 225

  template {
    settings = jsonencode({
      number_of_replicas     = 0
      number_of_shards       = 1
      "index.lifecycle.name" = elasticstack_elasticsearch_index_lifecycle.homelab_logs_30d.name
    })
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# Kibana Space & Data Views — per-service log navigation
# ──────────────────────────────────────────────────────────────────────────────

resource "elasticstack_kibana_space" "homelab" {
  space_id    = "homelab"
  name        = "homelab"
  description = "homelab infrastructure monitoring"
  color       = "#0077CC"
  initials    = "HL"
}

# Aggregate view — all services
resource "elasticstack_kibana_data_view" "logs" {
  data_view = {
    name            = "Logs"
    title           = "logs-*"
    time_field_name = "@timestamp"
  }
  space_id = elasticstack_kibana_space.homelab.space_id
}

# Per-service views — one data view per registered service
resource "elasticstack_kibana_data_view" "service_logs" {
  for_each = local.log_services

  data_view = {
    name            = "${each.value.name} Logs"
    title           = "logs-${each.key}-*"
    time_field_name = "@timestamp"
  }
  space_id = elasticstack_kibana_space.homelab.space_id
}

# ──────────────────────────────────────────────────────────────────────────────
# Snapshot Repository — automated backup target for ES indices
# ──────────────────────────────────────────────────────────────────────────────

resource "elasticstack_elasticsearch_snapshot_repository" "homelab_backups" {
  name = "homelab-backups"

  fs {
    location                  = "/usr/share/elasticsearch/data/backup"
    compress                  = true
    max_restore_bytes_per_sec = "40mb"
  }
}
