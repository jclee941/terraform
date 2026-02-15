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

resource "elasticstack_elasticsearch_index_template" "elastalert" {
  name           = "elastalert-template"
  index_patterns = ["elastalert_*"]
  priority       = 50

  template {
    settings = jsonencode({
      number_of_replicas     = 0
      number_of_shards       = 1
      "index.lifecycle.name" = elasticstack_elasticsearch_index_lifecycle.homelab_logs_30d.name
    })
  }
}
