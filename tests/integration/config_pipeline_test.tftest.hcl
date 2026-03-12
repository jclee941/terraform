# =============================================================================
# Config Pipeline Integration Tests
# =============================================================================
# Tests the config-renderer module with realistic template variables.
# Validates that templates render correctly with the hosts map pattern
# introduced in the config pipeline simplification (Part 1).
# =============================================================================

variables {
  fixture_route_path    = "fixtures/test-route.yml.tftpl"
  fixture_filebeat_path = "fixtures/test-filebeat.yml.tftpl"
  output_root           = "tmp"
}

# -----------------------------------------------------------------------------
# Test 1: Config renderer renders route template with hosts map
# -----------------------------------------------------------------------------
run "config_renderer_with_hosts_map" {
  command = apply

  module {
    source = "../../modules/proxmox/config-renderer"
  }

  variables {
    template_vars = {
      hosts = {
        elk = {
          vmid  = 105
          ip    = "192.168.50.105"
          roles = ["logging"]
          ports = {
            elasticsearch = 9200
            kibana        = 5601
            logstash_beat = 5044
          }
        }
      }
      domain = "jclee.me"
    }

    output_dir = "${var.output_root}/config-renderer-hosts-map"
    template_files = {
      test_route = {
        source = var.fixture_route_path
        output = "test-route.yml"
      }
    }
  }

  assert {
    condition     = contains(keys(output.rendered_configs), "test_route")
    error_message = "rendered_configs must include test_route entry"
  }

  assert {
    condition     = strcontains(output.rendered_configs.test_route, "Host(`test.jclee.me`)")
    error_message = "route template must render domain into Host rule"
  }

  assert {
    condition     = strcontains(output.rendered_configs.test_route, "http://192.168.50.105:9200")
    error_message = "route template must render elk endpoint via hosts map"
  }
}

# -----------------------------------------------------------------------------
# Test 2: Full pipeline with realistic hosts map
# -----------------------------------------------------------------------------
run "full_pipeline_traefik_route" {
  command = apply

  module {
    source = "../../modules/proxmox/config-renderer"
  }

  variables {
    template_vars = {
      hosts = {
        traefik = {
          vmid  = 102
          ip    = "192.168.50.102"
          roles = ["proxy", "ingress"]
          ports = {
            http    = 80
            https   = 443
            traefik = 8080
          }
        }

        elk = {
          vmid  = 105
          ip    = "192.168.50.105"
          roles = ["logging", "elasticsearch", "kibana"]
          ports = {
            elasticsearch = 9200
            es_transport  = 9300
            kibana        = 5601
            logstash_beat = 5044
            logstash_tcp  = 5000
            logstash_api  = 9600
          }
        }

        grafana = {
          vmid  = 104
          ip    = "192.168.50.104"
          roles = ["observability", "monitoring"]
          ports = {
            grafana    = 3000
            prometheus = 9090
          }
        }

        supabase = {
          vmid  = 107
          ip    = "192.168.50.107"
          roles = ["database", "backend"]
          ports = {
            api      = 8000
            studio   = 3000
            postgres = 5432
          }
        }

        mcphub = {
          vmid  = 112
          ip    = "192.168.50.112"
          roles = ["mcp-hub", "ai", "mcp", "gateway", "automation"]
          ports = {
            web        = 3000
            n8n        = 5678
            vault      = 8200
            proxmox    = 8055
            playwright = 8056
          }
        }

        synology = {
          vmid  = 215
          ip    = "192.168.50.215"
          roles = ["nas", "storage"]
          ports = {
            dsm = 5000
          }
        }
      }

      domain = "jclee.me"
    }

    output_dir = "${var.output_root}/full-pipeline-traefik-route"
    template_files = {
      test_route = {
        source = var.fixture_route_path
        output = "traefik/test-route.yml"
      }
    }
  }

  assert {
    condition     = contains(keys(output.rendered_configs), "test_route")
    error_message = "full pipeline render must produce test_route entry"
  }

  assert {
    condition     = strcontains(output.rendered_configs.test_route, "http:") && strcontains(output.rendered_configs.test_route, "routers:")
    error_message = "rendered route must keep YAML-like structure"
  }

  assert {
    condition     = strcontains(output.rendered_configs.test_route, "Host(`test.jclee.me`)")
    error_message = "rendered route must substitute domain"
  }

  assert {
    condition     = strcontains(output.rendered_configs.test_route, "http://192.168.50.105:9200")
    error_message = "rendered route must substitute ELK backend via hosts map"
  }

  assert {
    condition     = !strcontains(output.rendered_configs.test_route, "$${")
    error_message = "rendered route must not contain unresolved template variables"
  }
}

# -----------------------------------------------------------------------------
# Test 3: Multiple templates rendered in single pass
# -----------------------------------------------------------------------------
run "pipeline_multiple_templates" {
  command = apply

  module {
    source = "../../modules/proxmox/config-renderer"
  }

  variables {
    template_vars = {
      hosts = {
        elk = {
          vmid  = 105
          ip    = "192.168.50.105"
          roles = ["logging"]
          ports = {
            elasticsearch = 9200
            kibana        = 5601
            logstash_beat = 5044
          }
        }
      }

      domain        = "jclee.me"
      logstash_host = "192.168.50.105"
      logstash_port = 5044
    }

    output_dir = "${var.output_root}/pipeline-multiple-templates"
    template_files = {
      test_route = {
        source = var.fixture_route_path
        output = "traefik/test-route.yml"
      }
      test_filebeat = {
        source = var.fixture_filebeat_path
        output = "elk/test-filebeat.yml"
      }
    }
  }

  assert {
    condition     = contains(keys(output.rendered_configs), "test_route") && contains(keys(output.rendered_configs), "test_filebeat")
    error_message = "renderer must produce both template outputs"
  }

  assert {
    condition     = strcontains(output.rendered_configs.test_route, "http://192.168.50.105:9200")
    error_message = "test_route must render ELK backend endpoint via hosts map"
  }

  assert {
    condition     = strcontains(output.rendered_configs.test_filebeat, "hosts: [\"192.168.50.105:5044\"]")
    error_message = "test_filebeat must render logstash host and port"
  }

  assert {
    condition     = !strcontains(output.rendered_configs.test_route, "$${") && !strcontains(output.rendered_configs.test_filebeat, "$${")
    error_message = "all rendered templates must resolve placeholder variables"
  }
}
