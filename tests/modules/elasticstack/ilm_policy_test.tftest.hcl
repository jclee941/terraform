mock_provider "elasticstack" {}

run "ilm_policy_outputs_policy_name" {
  command = apply

  module {
    source = "../../../modules/elasticstack/ilm_policy"
  }

  variables {
    name    = "homelab-logs-30d"
    min_age = "30d"
  }

  assert {
    condition     = output.name == "homelab-logs-30d"
    error_message = "ILM policy module should output the managed policy name."
  }
}

run "ilm_policy_allows_custom_priority" {
  command = apply

  module {
    source = "../../../modules/elasticstack/ilm_policy"
  }

  variables {
    name     = "homelab-logs-critical-90d"
    min_age  = "90d"
    priority = 200
  }

  assert {
    condition     = output.name == "homelab-logs-critical-90d"
    error_message = "ILM policy module should keep the configured policy name with custom priority."
  }
}

run "ilm_policy_compacts_inactive_indices" {
  command = plan

  module {
    source = "../../../modules/elasticstack/ilm_policy"
  }

  variables {
    name         = "homelab-logs-30d"
    min_age      = "30d"
    warm_min_age = "7d"
  }

  assert {
    condition = (
      elasticstack_elasticsearch_index_lifecycle.this.warm.min_age == "7d" &&
      elasticstack_elasticsearch_index_lifecycle.this.warm.forcemerge.max_num_segments == 1 &&
      elasticstack_elasticsearch_index_lifecycle.this.warm.forcemerge.index_codec == null
    )
    error_message = "Inactive log indices must be force-merged without closing them for a codec change."
  }
}
