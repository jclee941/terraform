# ──────────────────────────────────────────────────────────────────────────────
# Service Registry — SSoT for all known log-producing services
# ──────────────────────────────────────────────────────────────────────────────

locals {
  # Service key must match the `service` field set by Logstash (logstash.conf.tftpl).
  # Tier determines ILM retention: critical=90d, standard=30d, ephemeral=7d.
  log_services = {
    auth               = { name = "Auth", tier = "standard" }
    cloudflare-workers = { name = "Cloudflare Workers", tier = "standard" }
    docker             = { name = "Docker", tier = "standard" }
    elk                = { name = "ELK", tier = "critical" }
    github-runner      = { name = "GitHub Runner", tier = "ephemeral" }
    opencode           = { name = "OpenCode", tier = "standard" }
    pve                = { name = "PVE", tier = "critical" }
    synology           = { name = "Synology", tier = "standard" }
    system             = { name = "System", tier = "standard" }
    youtube            = { name = "YouTube", tier = "ephemeral" }
  }

  # Derive index patterns from registry for index template assignment
  critical_patterns  = [for k, v in local.log_services : "logs-${k}-*" if v.tier == "critical"]
  ephemeral_patterns = [for k, v in local.log_services : "logs-${k}-*" if v.tier == "ephemeral"]

  ilm_policies = {
    logs_30d = {
      name    = "homelab-logs-30d"
      min_age = "30d"
    }
    logs_critical_90d = {
      name    = "homelab-logs-critical-90d"
      min_age = "90d"
    }
    logs_ephemeral_7d = {
      name    = "homelab-logs-ephemeral-7d"
      min_age = "7d"
    }
  }

  index_templates = {
    logs = {
      name                  = "logs-template"
      index_patterns        = ["logs-*"]
      priority              = 200
      lifecycle_policy_name = module.ilm["logs_30d"].name
      number_of_replicas    = 0
      number_of_shards      = 1
    }
    logs_critical = {
      name                  = "logs-critical"
      index_patterns        = local.critical_patterns
      priority              = 300
      lifecycle_policy_name = module.ilm["logs_critical_90d"].name
      number_of_replicas    = 0
      number_of_shards      = 1
    }
    logs_ephemeral = {
      name                  = "logs-ephemeral"
      index_patterns        = local.ephemeral_patterns
      priority              = 250
      lifecycle_policy_name = module.ilm["logs_ephemeral_7d"].name
      number_of_replicas    = 0
      number_of_shards      = 1
    }
    logs_cloudflare_workers = {
      name                  = "logs-cloudflare-workers"
      index_patterns        = ["logs-cloudflare-workers-*"]
      priority              = 225
      lifecycle_policy_name = module.ilm["logs_30d"].name
      number_of_replicas    = 0
      number_of_shards      = 1
    }
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# ILM Policies — tiered retention
# ──────────────────────────────────────────────────────────────────────────────

module "ilm" {
  source = "../../modules/elasticstack/ilm_policy"

  for_each = local.ilm_policies

  name    = each.value.name
  min_age = each.value.min_age
}

# ──────────────────────────────────────────────────────────────────────────────
# Index Templates — tier-based ILM assignment
# ──────────────────────────────────────────────────────────────────────────────

# Standard tier: catch-all for remaining services (30d retention, lowest priority)
module "index_templates" {
  source = "../../modules/elasticstack/index_template"

  for_each = local.index_templates

  depends_on = [module.ilm]

  name                  = each.value.name
  index_patterns        = each.value.index_patterns
  lifecycle_policy_name = each.value.lifecycle_policy_name
  number_of_replicas    = each.value.number_of_replicas
  number_of_shards      = each.value.number_of_shards
  priority              = each.value.priority
}

moved {
  from = elasticstack_elasticsearch_index_lifecycle.homelab_logs_30d
  to   = module.ilm["logs_30d"].elasticstack_elasticsearch_index_lifecycle.this
}

moved {
  from = elasticstack_elasticsearch_index_lifecycle.homelab_logs_critical_90d
  to   = module.ilm["logs_critical_90d"].elasticstack_elasticsearch_index_lifecycle.this
}

moved {
  from = elasticstack_elasticsearch_index_lifecycle.homelab_logs_ephemeral_7d
  to   = module.ilm["logs_ephemeral_7d"].elasticstack_elasticsearch_index_lifecycle.this
}

moved {
  from = elasticstack_elasticsearch_index_template.logs
  to   = module.index_templates["logs"].elasticstack_elasticsearch_index_template.this
}

moved {
  from = elasticstack_elasticsearch_index_template.logs_critical
  to   = module.index_templates["logs_critical"].elasticstack_elasticsearch_index_template.this
}

moved {
  from = elasticstack_elasticsearch_index_template.logs_ephemeral
  to   = module.index_templates["logs_ephemeral"].elasticstack_elasticsearch_index_template.this
}

moved {
  from = elasticstack_elasticsearch_index_template.logs_cloudflare_workers
  to   = module.index_templates["logs_cloudflare_workers"].elasticstack_elasticsearch_index_template.this
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
    location                  = "/usr/share/elasticsearch/snapshots"
    compress                  = true
    max_restore_bytes_per_sec = "40mb"
  }
}
