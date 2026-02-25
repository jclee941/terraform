provider "elasticstack" {
  elasticsearch {
    endpoints = [var.elasticsearch_url]
    username  = var.elasticsearch_username
    password  = local.effective_elasticsearch_password
  }

  kibana {
    endpoints = [var.kibana_url]
    username  = var.elasticsearch_username
    password  = local.effective_elasticsearch_password
  }
}

provider "onepassword" {}
