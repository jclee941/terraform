terraform {
  required_version = ">= 1.7, < 2.0"

  required_providers {
    elasticstack = {
      source  = "elastic/elasticstack"
      version = ">= 0.13"
    }
  }
}

resource "elasticstack_elasticsearch_index_template" "this" {
  name           = var.name
  index_patterns = var.index_patterns
  priority       = var.priority

  template {
    settings = jsonencode({
      number_of_replicas     = var.number_of_replicas
      number_of_shards       = var.number_of_shards
      "index.lifecycle.name" = var.lifecycle_policy_name
    })
  }
}
