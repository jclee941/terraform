mock_provider "elasticstack" {}

run "index_template_outputs_template_name" {
  command = apply

  module {
    source = "../../../modules/elasticstack/index_template"
  }

  variables {
    name                  = "logs-template"
    index_patterns        = ["logs-*"]
    priority              = 200
    lifecycle_policy_name = "homelab-logs-30d"
  }

  assert {
    condition     = output.name == "logs-template"
    error_message = "Index template module should output the managed template name."
  }
}

run "index_template_accepts_custom_settings" {
  command = apply

  module {
    source = "../../../modules/elasticstack/index_template"
  }

  variables {
    name                  = "logs-critical"
    index_patterns        = ["logs-elk-*", "logs-pve-*"]
    priority              = 300
    lifecycle_policy_name = "homelab-logs-critical-90d"
    number_of_replicas    = 1
    number_of_shards      = 2
  }

  assert {
    condition     = output.name == "logs-critical"
    error_message = "Index template module should keep the configured template name with custom settings."
  }
}

run "index_template_applies_log_storage_optimizations" {
  command = plan

  module {
    source = "../../../modules/elasticstack/index_template"
  }

  variables {
    name                  = "logs-template"
    index_patterns        = ["logs-*"]
    priority              = 200
    lifecycle_policy_name = "homelab-logs-30d"
    index_codec           = "best_compression"
    refresh_interval      = "30s"
  }

  assert {
    condition = (
      jsondecode(elasticstack_elasticsearch_index_template.this.template.settings)["index.codec"] == "best_compression" &&
      jsondecode(elasticstack_elasticsearch_index_template.this.template.settings)["index.refresh_interval"] == "30s"
    )
    error_message = "Log index templates must enable best_compression and a 30-second refresh interval."
  }
}
