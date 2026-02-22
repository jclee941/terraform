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


resource "elasticstack_elasticsearch_index_template" "filebeat" {
  name           = "filebeat-template"
  index_patterns = ["filebeat-*"]
  priority       = 150

  template {
    settings = jsonencode({
      number_of_replicas     = 0
      number_of_shards       = 1
      "index.lifecycle.name" = elasticstack_elasticsearch_index_lifecycle.homelab_logs_30d.name
    })

    mappings = jsonencode({
      properties = {
        "@timestamp"   = { type = "date" }
        message        = { type = "text" }
        host           = { properties = { name = { type = "keyword" } } }
        container      = { properties = { name = { type = "keyword" }, id = { type = "keyword" } } }
        service        = { type = "keyword" }
        level          = { type = "keyword" }
        error_severity = { type = "keyword" }
      }
    })
  }
}

resource "elasticstack_elasticsearch_index_lifecycle" "filebeat_90d" {
  name = "filebeat-90d"

  hot {
    set_priority {
      priority = 50
    }
  }

  warm {
    min_age = "7d"
    set_priority {
      priority = 25
    }
    forcemerge {
      max_num_segments = 1
    }
  }

  delete {
    min_age = "90d"
    delete {}
  }
}

resource "elasticstack_kibana_space" "homelab" {
  space_id    = "homelab"
  name        = "homelab"
  description = "homelab infrastructure monitoring"
  color       = "#0077CC"
  initials    = "HL"
}

resource "elasticstack_kibana_data_view" "logs" {
  data_view = {
    name            = "Logs"
    title           = "logs-*"
    time_field_name = "@timestamp"
  }
  space_id = elasticstack_kibana_space.homelab.space_id
}

resource "elasticstack_kibana_data_view" "filebeat" {
  data_view = {
    name            = "Filebeat"
    title           = "filebeat-*"
    time_field_name = "@timestamp"
  }
  space_id = elasticstack_kibana_space.homelab.space_id
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

resource "elasticstack_elasticsearch_index_template" "logs_critical" {
  name           = "logs-critical"
  index_patterns = ["logs-elk-*", "logs-supabase-*", "logs-grafana-*", "logs-archon-*"]
  priority       = 300

  template {
    settings = jsonencode({
      number_of_replicas     = 0
      number_of_shards       = 1
      "index.lifecycle.name" = elasticstack_elasticsearch_index_lifecycle.homelab_logs_critical_90d.name
    })
  }
}

resource "elasticstack_elasticsearch_index_template" "logs_ephemeral" {
  name           = "logs-ephemeral"
  index_patterns = ["logs-unknown-*", "logs-debug-*", "logs-runner-*"]
  priority       = 250

  template {
    settings = jsonencode({
      number_of_replicas     = 0
      number_of_shards       = 1
      "index.lifecycle.name" = elasticstack_elasticsearch_index_lifecycle.homelab_logs_ephemeral_7d.name
    })
  }
}
