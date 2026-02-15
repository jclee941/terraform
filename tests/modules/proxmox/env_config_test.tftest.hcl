# =============================================================================
# Env Config Module Tests
# =============================================================================
# Module: modules/proxmox/env-config
# Type: Pure logic module (no providers/resources)
# Purpose: Validate host inventory transformations, service URL derivation,
#          template variables, and default network behavior.
# =============================================================================

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
      roles = ["proxy"]
      ports = {
        web       = 80
        websecure = 443
        dashboard = 8080
      }
    }

    grafana = {
      vmid  = 104
      ip    = "192.168.50.104"
      roles = ["monitoring"]
      ports = {
        prometheus = 9090
        grafana    = 3000
      }
    }

    elk = {
      vmid  = 105
      ip    = "192.168.50.105"
      roles = ["logging"]
      ports = {
        elasticsearch   = 9200
        kibana          = 5601
        logstash_beat   = 5044
        logstash_syslog = 5000
      }
    }

    glitchtip = {
      vmid  = 106
      ip    = "192.168.50.106"
      roles = ["error-tracking"]
      ports = {
        web = 8000
      }
    }

    supabase = {
      vmid  = 107
      ip    = "192.168.50.107"
      roles = ["database"]
      ports = {
        api    = 8000
        studio = 3001
      }
    }

    archon = {
      vmid  = 108
      ip    = "192.168.50.108"
      roles = ["ai"]
      ports = {
        ui     = 3737
        server = 8181
        mcp    = 8051
      }
    }

    mcphub = {
      vmid  = 112
      ip    = "192.168.50.112"
      roles = ["mcp"]
      ports = {
        web        = 3000
        n8n        = 5678
        vault      = 8200
        playwright = 8056
        github     = 8058
        terraform  = 8071
      }
    }

    synology = {
      vmid  = 215
      ip    = "192.168.50.215"
      roles = ["nas"]
      ports = {
        smb          = 445
        file_station = 5000
      }
    }
  }
}

# -----------------------------------------------------------------------------
# Test 1: Hosts input is passed through unchanged
# -----------------------------------------------------------------------------
run "test_basic_host_passthrough" {
  command = plan

  module {
    source = "../../../modules/proxmox/env-config"
  }

  assert {
    condition = toset(keys(output.hosts)) == toset([
      "archon",
      "elk",
      "glitchtip",
      "grafana",
      "mcphub",
      "pve",
      "supabase",
      "synology",
      "traefik",
    ])
    error_message = "hosts output must contain exactly the input host keys"
  }

  assert {
    condition     = output.hosts["pve"].vmid == 100
    error_message = "hosts.pve.vmid must be 100"
  }

  assert {
    condition     = output.hosts["pve"].ip == "192.168.50.100"
    error_message = "hosts.pve.ip must be 192.168.50.100"
  }

  assert {
    condition     = contains(output.hosts["pve"].roles, "hypervisor")
    error_message = "hosts.pve.roles must contain hypervisor"
  }

  assert {
    condition     = length(output.hosts["pve"].ports) == 0
    error_message = "hosts.pve.ports must be empty"
  }

  assert {
    condition     = output.hosts["elk"].vmid == 105
    error_message = "hosts.elk.vmid must be 105"
  }

  assert {
    condition     = output.hosts["elk"].ip == "192.168.50.105"
    error_message = "hosts.elk.ip must be 192.168.50.105"
  }

  assert {
    condition     = output.hosts["elk"].ports.elasticsearch == 9200
    error_message = "hosts.elk.ports.elasticsearch must be 9200"
  }

  assert {
    condition     = output.hosts["mcphub"].vmid == 112
    error_message = "hosts.mcphub.vmid must be 112"
  }

  assert {
    condition     = output.hosts["mcphub"].ip == "192.168.50.112"
    error_message = "hosts.mcphub.ip must be 192.168.50.112"
  }

  assert {
    condition     = output.hosts["mcphub"].ports.web == 3000
    error_message = "hosts.mcphub.ports.web must be 3000"
  }

  assert {
    condition     = output.hosts["mcphub"].ports.n8n == 5678
    error_message = "hosts.mcphub.ports.n8n must be 5678"
  }
}

# -----------------------------------------------------------------------------
# Test 2: Service URLs are derived correctly from host IPs and ports
# -----------------------------------------------------------------------------
run "test_service_url_derivation" {
  command = plan

  module {
    source = "../../../modules/proxmox/env-config"
  }

  assert {
    condition = output.services == {
      elasticsearch_url = "http://192.168.50.105:9200"
      kibana_url        = "http://192.168.50.105:5601"
      logstash_beats    = "192.168.50.105:5044"
      prometheus_url    = "http://192.168.50.104:9090"
      grafana_url       = "http://192.168.50.104:3000"
      mcphub_url        = "http://192.168.50.112:3000"
      n8n_url           = "http://192.168.50.112:5678"
      supabase_url      = "http://192.168.50.107:8000"
      archon_url        = "http://192.168.50.108:3737"
    }
    error_message = "services output must derive all service URLs from host inventory"
  }

  assert {
    condition     = output.elasticsearch_url == "http://192.168.50.105:9200"
    error_message = "elasticsearch_url must use ELK IP and elasticsearch port"
  }

  assert {
    condition     = output.kibana_url == "http://192.168.50.105:5601"
    error_message = "kibana_url must use ELK IP and kibana port"
  }

  assert {
    condition     = output.logstash_beats == "192.168.50.105:5044"
    error_message = "logstash_beats must use ELK IP and logstash beat port"
  }

  assert {
    condition     = output.prometheus_url == "http://192.168.50.104:9090"
    error_message = "prometheus_url must use Grafana host IP and prometheus port"
  }

  assert {
    condition     = output.grafana_url == "http://192.168.50.104:3000"
    error_message = "grafana_url must use Grafana host IP and grafana port"
  }

  assert {
    condition     = output.mcphub_url == "http://192.168.50.112:3000"
    error_message = "mcphub_url must use MCPHub IP and web port"
  }

  assert {
    condition     = output.n8n_url == "http://192.168.50.112:5678"
    error_message = "n8n_url must use MCPHub IP and n8n port"
  }
}

# -----------------------------------------------------------------------------
# Test 3: Prometheus node targets include non-hypervisors and exclude hypervisor
# -----------------------------------------------------------------------------
run "test_prometheus_node_targets" {
  command = plan

  module {
    source = "../../../modules/proxmox/env-config"
  }

  assert {
    condition = toset(output.prometheus_node_targets) == toset([
      "192.168.50.102:9100",
      "192.168.50.104:9100",
      "192.168.50.105:9100",
      "192.168.50.106:9100",
      "192.168.50.107:9100",
      "192.168.50.108:9100",
      "192.168.50.112:9100",
      "192.168.50.215:9100",
    ])
    error_message = "prometheus_node_targets must include all non-hypervisor hosts with :9100 suffix"
  }

  assert {
    condition     = !contains(output.prometheus_node_targets, "192.168.50.100:9100")
    error_message = "prometheus_node_targets must exclude hypervisor node pve"
  }
}

# -----------------------------------------------------------------------------
# Test 4: MCP server URLs map mcphub ports to SSE endpoints
# -----------------------------------------------------------------------------
run "test_mcp_server_urls" {
  command = plan

  module {
    source = "../../../modules/proxmox/env-config"
  }

  assert {
    condition = output.mcp_server_urls == {
      web        = "http://192.168.50.112:3000/sse"
      n8n        = "http://192.168.50.112:5678/sse"
      vault      = "http://192.168.50.112:8200/sse"
      playwright = "http://192.168.50.112:8056/sse"
      github     = "http://192.168.50.112:8058/sse"
      terraform  = "http://192.168.50.112:8071/sse"
    }
    error_message = "mcp_server_urls must map each mcphub port to http://ip:port/sse"
  }
}

# -----------------------------------------------------------------------------
# Test 5: Traefik backends include only hosts that expose ports
# -----------------------------------------------------------------------------
run "test_traefik_backends" {
  command = plan

  module {
    source = "../../../modules/proxmox/env-config"
  }

  assert {
    condition = toset(keys(output.traefik_backends)) == toset([
      "archon",
      "elk",
      "glitchtip",
      "grafana",
      "mcphub",
      "supabase",
      "synology",
      "traefik",
    ])
    error_message = "traefik_backends must include all hosts with one or more exposed ports"
  }

  assert {
    condition     = !contains(keys(output.traefik_backends), "pve")
    error_message = "traefik_backends must exclude hosts with empty ports map"
  }

  assert {
    condition     = output.traefik_backends["elk"].ip == "192.168.50.105"
    error_message = "traefik_backends.elk.ip must match ELK host IP"
  }

  assert {
    condition     = output.traefik_backends["elk"].ports.elasticsearch == 9200
    error_message = "traefik_backends.elk.ports must preserve ELK port mappings"
  }
}

# -----------------------------------------------------------------------------
# Test 6: Infrastructure nodes include name/ip/vmid for non-hypervisor hosts
# -----------------------------------------------------------------------------
run "test_infrastructure_nodes" {
  command = plan

  module {
    source = "../../../modules/proxmox/env-config"
  }

  assert {
    condition     = length(output.infrastructure_nodes) == 8
    error_message = "infrastructure_nodes must include exactly all non-hypervisor hosts"
  }

  assert {
    condition     = !contains([for node in output.infrastructure_nodes : node.name], "pve")
    error_message = "infrastructure_nodes must exclude hypervisor hosts"
  }

  assert {
    condition = contains(output.infrastructure_nodes, {
      name = "elk"
      ip   = "192.168.50.105"
      vmid = 105
    })
    error_message = "infrastructure_nodes must include ELK node metadata"
  }

  assert {
    condition = contains(output.infrastructure_nodes, {
      name = "mcphub"
      ip   = "192.168.50.112"
      vmid = 112
    })
    error_message = "infrastructure_nodes must include MCPHub node metadata"
  }
}

# -----------------------------------------------------------------------------
# Test 7: Template vars include ELK defaults used by rendered configs
# -----------------------------------------------------------------------------
run "test_template_vars_elk_defaults" {
  command = plan

  module {
    source = "../../../modules/proxmox/env-config"
  }

  assert {
    condition     = output.template_vars.elk_version == "8.12.0"
    error_message = "template_vars.elk_version must default to 8.12.0"
  }

  assert {
    condition     = output.template_vars.es_heap == "2g"
    error_message = "template_vars.es_heap must default to 2g"
  }

  assert {
    condition     = output.template_vars.logstash_heap == "512m"
    error_message = "template_vars.logstash_heap must default to 512m"
  }

  assert {
    condition     = output.template_vars.ilm_delete_after == "30d"
    error_message = "template_vars.ilm_delete_after must default to 30d"
  }

  assert {
    condition     = output.template_vars.ilm_policy_name == "homelab-logs-30d"
    error_message = "template_vars.ilm_policy_name must default to homelab-logs-30d"
  }
}

# -----------------------------------------------------------------------------
# Test 8: Template vars include Grafana SLA target and period defaults
# -----------------------------------------------------------------------------
run "test_template_vars_sla_defaults" {
  command = plan

  module {
    source = "../../../modules/proxmox/env-config"
  }

  assert {
    condition     = output.template_vars.sla_target_percentage == "99.9"
    error_message = "template_vars.sla_target_percentage must default to 99.9"
  }

  assert {
    condition     = output.template_vars.prometheus_datasource_uid == "prometheus"
    error_message = "template_vars.prometheus_datasource_uid must default to prometheus"
  }
}

# -----------------------------------------------------------------------------
# Test 9: Network output uses module defaults when input is not provided
# -----------------------------------------------------------------------------
run "test_network_defaults" {
  command = plan

  module {
    source = "../../../modules/proxmox/env-config"
  }

  assert {
    condition = output.network == {
      subnet  = "192.168.50.0/24"
      gateway = "192.168.50.1"
      domain  = "jclee.me"
    }
    error_message = "network output must use default subnet, gateway, and domain values"
  }
}

# NOTE: Empty hosts test intentionally omitted. The env-config module requires
# specific host keys (elk, grafana, mcphub, archon, supabase, synology) via
# direct attribute access (var.hosts.elk.ip). Empty or partial maps are invalid.
