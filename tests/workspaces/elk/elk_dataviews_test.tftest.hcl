# ============================================================================
# ELK workspace per-service data view and registry tests
# ============================================================================
#
# Validates the log_services registry, derived index patterns, and
# per-service Kibana data view creation in 105-elk/terraform/.
# Convention: positive plan assertions against registry-derived resources.
# All tests are plan-only with mocked providers.
# ============================================================================

mock_provider "elasticstack" {}
mock_provider "onepassword" {}

override_module {
  target = module.onepassword_secrets
  outputs = {
    secrets = {
      elk_elastic_password = "mock-elastic-password" # pragma: allowlist secret
    }
    metadata = {
      vault_name = "homelab"
    }
  }
}

# --- service registry produces correct data view count ---

run "service_registry_creates_expected_data_views" {
  command = plan

  module {
    source = "../../../105-elk/terraform"
  }

  assert {
    condition     = length(elasticstack_kibana_data_view.service_logs) == 14
    error_message = "Expected 14 per-service data views from log_services registry"
  }
}

# --- critical tier: index template patterns derived from registry ---

run "critical_index_template_patterns_derived_from_registry" {
  command = plan

  module {
    source = "../../../105-elk/terraform"
  }

  assert {
    condition     = length(elasticstack_elasticsearch_index_template.logs_critical.index_patterns) == 5
    error_message = "Critical template should have 5 patterns (archon, elk, grafana, pve, supabase)"
  }

  assert {
    condition     = contains(elasticstack_elasticsearch_index_template.logs_critical.index_patterns, "logs-archon-*")
    error_message = "Critical template should include logs-archon-*"
  }

  assert {
    condition     = contains(elasticstack_elasticsearch_index_template.logs_critical.index_patterns, "logs-pve-*")
    error_message = "Critical template should include logs-pve-*"
  }

  assert {
    condition     = contains(elasticstack_elasticsearch_index_template.logs_critical.index_patterns, "logs-supabase-*")
    error_message = "Critical template should include logs-supabase-*"
  }
}

# --- ephemeral tier: index template patterns derived from registry ---

run "ephemeral_index_template_patterns_derived_from_registry" {
  command = plan

  module {
    source = "../../../105-elk/terraform"
  }

  assert {
    condition     = length(elasticstack_elasticsearch_index_template.logs_ephemeral.index_patterns) == 2
    error_message = "Ephemeral template should have 2 patterns (github-runner, youtube)"
  }

  assert {
    condition     = contains(elasticstack_elasticsearch_index_template.logs_ephemeral.index_patterns, "logs-github-runner-*")
    error_message = "Ephemeral template should include logs-github-runner-*"
  }

  assert {
    condition     = contains(elasticstack_elasticsearch_index_template.logs_ephemeral.index_patterns, "logs-youtube-*")
    error_message = "Ephemeral template should include logs-youtube-*"
  }
}

# --- template priority ordering: critical > ephemeral > catch-all ---

run "index_template_priority_ordering" {
  command = plan

  module {
    source = "../../../105-elk/terraform"
  }

  assert {
    condition     = elasticstack_elasticsearch_index_template.logs_critical.priority == 300
    error_message = "Critical template should have highest priority (300)"
  }

  assert {
    condition     = elasticstack_elasticsearch_index_template.logs_ephemeral.priority == 250
    error_message = "Ephemeral template should have medium priority (250)"
  }

  assert {
    condition     = elasticstack_elasticsearch_index_template.logs.priority == 200
    error_message = "Standard catch-all template should have lowest priority (200)"
  }

  assert {
    condition     = contains(elasticstack_elasticsearch_index_template.logs.index_patterns, "logs-*") && length(elasticstack_elasticsearch_index_template.logs.index_patterns) == 1
    error_message = "Standard template should use catch-all logs-* pattern"
  }
}
