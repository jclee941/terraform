variables {
  fixture_route_path    = "fixtures/test-route.yml.tftpl"
  fixture_filebeat_path = "fixtures/test-filebeat.yml.tftpl"
  output_root           = "tmp"
}

run "env_config_produces_template_vars" {
  command = plan

  module {
    source = "../../modules/proxmox/env-config"
  }

  variables {
    hosts = {
      pve = {
        vmid  = 100
        ip    = "192.168.50.100"
        roles = ["hypervisor"]
        ports = {}
      }

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

      glitchtip = {
        vmid  = 106
        ip    = "192.168.50.106"
        roles = ["error-tracking", "monitoring"]
        ports = {
          web      = 8000
          postgres = 5432
          redis    = 6379
        }
      }

      supabase = {
        vmid  = 107
        ip    = "192.168.50.107"
        roles = ["database", "backend-as-a-service", "auth"]
        ports = {
          studio   = 3000
          api      = 8000
          db       = 5432
          realtime = 4000
          inbucket = 9000
        }
      }

      archon = {
        vmid  = 108
        ip    = "192.168.50.108"
        roles = ["ai", "knowledge-management", "mcp"]
        ports = {
          ui     = 3737
          server = 8181
          mcp    = 8051
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

    network = {
      subnet  = "192.168.50.0/24"
      gateway = "192.168.50.1"
      domain  = "jclee.me"
    }
  }

  assert {
    condition     = output.template_vars.elk_ip == "192.168.50.105"
    error_message = "template_vars.elk_ip must come from host inventory"
  }

  assert {
    condition     = output.template_vars.elasticsearch_port == 9200
    error_message = "template_vars.elasticsearch_port must match elk.elasticsearch port"
  }

  assert {
    condition     = output.template_vars.grafana_ip == "192.168.50.104"
    error_message = "template_vars.grafana_ip must come from host inventory"
  }

  assert {
    condition     = output.template_vars.domain == "jclee.me"
    error_message = "template_vars.domain must come from network.domain"
  }

  assert {
    condition     = output.services.elasticsearch_url == "http://192.168.50.105:9200"
    error_message = "services.elasticsearch_url must be derived correctly"
  }

  assert {
    condition     = output.services.grafana_url == "http://192.168.50.104:3000"
    error_message = "services.grafana_url must be derived correctly"
  }

  assert {
    condition     = !contains(output.prometheus_node_targets, "192.168.50.100:9100")
    error_message = "prometheus targets must exclude hypervisor node"
  }

  assert {
    condition     = contains(output.prometheus_node_targets, "192.168.50.105:9100")
    error_message = "prometheus targets must include non-hypervisor infrastructure nodes"
  }

  assert {
    condition     = !contains(keys(output.template_vars), "elk_port")
    error_message = "env-config should not expose elk_port (uses elasticsearch_port)"
  }

  assert {
    condition     = !can(templatefile(var.fixture_route_path, output.template_vars))
    error_message = "route template should fail with raw env-config vars when names mismatch"
  }
}

run "config_renderer_with_env_vars" {
  command = apply

  module {
    source = "../../modules/proxmox/config-renderer"
  }

  variables {
    template_vars = {
      elk_ip = "192.168.50.105"
      elk_ports = {
        elasticsearch = 9200
        kibana        = 5601
        logstash_beat = 5044
      }
      elasticsearch_port  = 9200
      kibana_port         = 5601
      logstash_beats_port = 5044
      domain              = "jclee.me"

      elk_port = 9200
    }

    output_dir = "${var.output_root}/config-renderer-with-env-vars"
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
    error_message = "route template must render elk endpoint"
  }
}

run "full_pipeline_traefik_route" {
  command = apply

  module {
    source = "../../modules/proxmox/config-renderer"
  }

  variables {
    template_vars = {
      elk_ip = "192.168.50.105"
      elk_ports = {
        elasticsearch = 9200
        es_transport  = 9300
        kibana        = 5601
        logstash_beat = 5044
        logstash_tcp  = 5000
        logstash_api  = 9600
      }
      elasticsearch_port   = 9200
      kibana_port          = 5601
      logstash_beats_port  = 5044
      logstash_syslog_port = 5000
      traefik_ip           = "192.168.50.102"
      traefik_ports = {
        http    = 80
        https   = 443
        traefik = 8080
      }
      grafana_ip = "192.168.50.104"
      grafana_ports = {
        grafana    = 3000
        prometheus = 9090
      }
      glitchtip_ip   = "192.168.50.106"
      glitchtip_port = 8000
      mcphub_ip      = "192.168.50.112"
      mcphub_port    = 3000
      n8n_ip         = "192.168.50.112"
      n8n_port       = 5678
      domain         = "jclee.me"
      infrastructure_nodes = [
        {
          name = "traefik"
          ip   = "192.168.50.102"
          vmid = 102
        },
        {
          name = "elk"
          ip   = "192.168.50.105"
          vmid = 105
        },
        {
          name = "grafana"
          ip   = "192.168.50.104"
          vmid = 104
        },
        {
          name = "glitchtip"
          ip   = "192.168.50.106"
          vmid = 106
        },
        {
          name = "supabase"
          ip   = "192.168.50.107"
          vmid = 107
        },
        {
          name = "archon"
          ip   = "192.168.50.108"
          vmid = 108
        },
        {
          name = "mcphub"
          ip   = "192.168.50.112"
          vmid = 112
        },
        {
          name = "synology"
          ip   = "192.168.50.215"
          vmid = 215
        },
      ]
      elk_version                 = "8.12.0"
      es_heap                     = "2g"
      logstash_heap               = "512m"
      logstash_dlq_size           = "1024mb"
      elastalert_version          = "2.19.0"
      elasticsearch_index_pattern = "logs-%%{+YYYY.MM.dd}"
      ilm_delete_after            = "30d"
      ilm_policy_name             = "homelab-logs-30d"
      synology_ip                 = "192.168.50.215"
      synology_ports = {
        dsm = 5000
      }
      supabase_ip     = "192.168.50.107"
      supabase_port   = 8000
      supabase_studio = 3000
      supabase_ports = {
        studio   = 3000
        api      = 8000
        db       = 5432
        realtime = 4000
        inbucket = 9000
      }
      archon_ip     = "192.168.50.108"
      archon_port   = 3737
      archon_server = 8181
      archon_mcp    = 8051
      vault_ip      = "192.168.50.112"
      vault_port    = 8200

      prometheus_datasource_uid = "prometheus"
      sla_target_percentage     = "99.9"

      elk_port = 9200
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
    error_message = "rendered route must substitute ELK backend"
  }

  assert {
    condition     = !strcontains(output.rendered_configs.test_route, "$${")
    error_message = "rendered route must not contain unresolved template variables"
  }
}

run "pipeline_multiple_templates" {
  command = apply

  module {
    source = "../../modules/proxmox/config-renderer"
  }

  variables {
    template_vars = {
      domain = "jclee.me"
      elk_ip = "192.168.50.105"

      elk_port      = 9200
      logstash_host = "192.168.50.105"
      logstash_port = 5044

      elasticsearch_port  = 9200
      logstash_beats_port = 5044
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
    error_message = "test_route must render ELK backend endpoint"
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
