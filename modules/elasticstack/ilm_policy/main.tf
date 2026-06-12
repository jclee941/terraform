terraform {
  required_version = ">= 1.7, < 2.0"

  required_providers {
    elasticstack = {
      source  = "elastic/elasticstack"
      version = ">= 0.13"
    }
  }
}

resource "elasticstack_elasticsearch_index_lifecycle" "this" {
  name = var.name

  hot {
    set_priority {
      priority = var.priority
    }
  }

  delete {
    min_age = var.min_age
    delete {}
  }
}
