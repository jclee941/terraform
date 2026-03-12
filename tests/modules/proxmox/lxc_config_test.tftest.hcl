run "test_single_container_with_service" {
  command = apply

  module {
    source = "../../../modules/proxmox/lxc-config"
  }

  variables {
    lxc_containers = {
      runner = {
        vmid       = 101
        hostname   = "runner"
        ip_address = "192.168.50.101"
        systemd_services = {
          github-runner = {
            description = "GitHub Actions runner service"
            exec_start  = "/usr/local/bin/runner.sh"
            working_dir = "/opt/actions-runner"
            user        = "runner"
            env_vars = {
              RUNNER_NAME = "runner-101"
            }
          }
        }
        deploy = false
      }
    }

    mcp_host             = "192.168.50.112"
    deploy_lxc_configs   = false
    enable_health_checks = false
  }

  assert {
    condition = (
      length(keys(output.lxc_configs)) == 1 &&
      contains(keys(output.lxc_configs), "runner") &&
      try(output.lxc_configs.runner.vmid, 0) == 101 &&
      try(output.lxc_configs.runner.hostname, "") == "runner" &&
      try(output.lxc_configs.runner.ip_address, "") == "192.168.50.101" &&
      length(try(output.lxc_configs.runner.systemd_services, [])) == 1 &&
      try(output.lxc_configs.runner.systemd_services[0].name, "") == "github-runner" &&
      endswith(try(output.lxc_configs.runner.systemd_services[0].path, ""), "/configs/lxc-101-runner/github-runner.service") &&
      length(try(output.lxc_configs.runner.config_files, [])) == 0 &&
      try(output.lxc_configs.runner.docker_compose, "not-null") == null &&
      output.service_count == 1
    )
    error_message = "single container output should include vm metadata, service path, empty config_files, null docker_compose, and service_count=1"
  }
}

run "test_multiple_containers" {
  command = apply

  module {
    source = "../../../modules/proxmox/lxc-config"
  }

  variables {
    lxc_containers = {
      traefik = {
        vmid       = 102
        hostname   = "traefik"
        ip_address = "192.168.50.102"
        systemd_services = {
          traefik = {
            description = "Traefik reverse proxy"
            exec_start  = "/usr/bin/docker compose up"
          }
        }
        deploy = false
      }
      grafana = {
        vmid       = 104
        hostname   = "grafana"
        ip_address = "192.168.50.104"
        deploy     = false
      }
    }

    mcp_host           = "192.168.50.112"
    deploy_lxc_configs = false
  }

  assert {
    condition = (
      length(keys(output.lxc_configs)) == 2 &&
      contains(keys(output.lxc_configs), "traefik") &&
      contains(keys(output.lxc_configs), "grafana") &&
      try(output.lxc_configs.traefik.vmid, 0) == 102 &&
      try(output.lxc_configs.traefik.hostname, "") == "traefik" &&
      try(output.lxc_configs.traefik.ip_address, "") == "192.168.50.102" &&
      try(output.lxc_configs.grafana.vmid, 0) == 104 &&
      try(output.lxc_configs.grafana.hostname, "") == "grafana" &&
      try(output.lxc_configs.grafana.ip_address, "") == "192.168.50.104" &&
      output.service_count == 1
    )
    error_message = "multiple containers should both appear in lxc_configs with correct vm metadata"
  }
}

run "test_service_count" {
  command = apply

  module {
    source = "../../../modules/proxmox/lxc-config"
  }

  variables {
    lxc_containers = {
      runner = {
        vmid       = 101
        hostname   = "runner"
        ip_address = "192.168.50.101"
        systemd_services = {
          runner = {
            description = "Runner service"
            exec_start  = "/usr/local/bin/runner"
          }
        }
        deploy = false
      }
      grafana = {
        vmid       = 104
        hostname   = "grafana"
        ip_address = "192.168.50.104"
        systemd_services = {
          prometheus-agent = {
            description = "Prometheus agent"
            exec_start  = "/usr/local/bin/prom-agent"
          }
          node-exporter = {
            description = "Node exporter"
            exec_start  = "/usr/local/bin/node-exporter"
          }
        }
        deploy = false
      }
      elk = {
        vmid       = 105
        hostname   = "elk"
        ip_address = "192.168.50.105"
        systemd_services = {
          logstash = {
            description = "Logstash"
            exec_start  = "/usr/share/logstash/bin/logstash"
          }
        }
        deploy = false
      }
    }

    mcp_host           = "192.168.50.112"
    deploy_lxc_configs = false
  }

  assert {
    condition = (
      output.service_count == 4 &&
      length(try(output.lxc_configs.runner.systemd_services, [])) == 1 &&
      length(try(output.lxc_configs.grafana.systemd_services, [])) == 2 &&
      length(try(output.lxc_configs.elk.systemd_services, [])) == 1
    )
    error_message = "service_count should equal total services across all containers"
  }
}

run "test_config_files_output" {
  command = apply

  module {
    source = "../../../modules/proxmox/lxc-config"
  }

  variables {
    lxc_containers = {
      sampleapp = {
        vmid       = 110
        hostname   = "sampleapp"
        ip_address = "192.168.50.110"
        config_files = {
          app-env = {
            path        = "/opt/sampleapp/.env"
            content     = "DEBUG=false"
            permissions = "0600"
          }
          smtp-config = {
            path    = "/opt/sampleapp/smtp.conf"
            content = "smtp_enabled=true"
          }
        }
        deploy = false
      }
    }

    mcp_host           = "192.168.50.112"
    deploy_lxc_configs = false
  }

  assert {
    condition = (
      length(try(output.lxc_configs.sampleapp.config_files, [])) == 2 &&
      try(output.lxc_configs.sampleapp.config_files[0].name, "") == "app-env" &&
      endswith(try(output.lxc_configs.sampleapp.config_files[0].path, ""), "/configs/lxc-110-sampleapp/app-env") &&
      try(output.lxc_configs.sampleapp.config_files[1].name, "") == "smtp-config" &&
      endswith(try(output.lxc_configs.sampleapp.config_files[1].path, ""), "/configs/lxc-110-sampleapp/smtp-config")
    )
    error_message = "config_files output should include expected file names and generated paths"
  }
}

run "test_docker_compose_output" {
  command = apply

  module {
    source = "../../../modules/proxmox/lxc-config"
  }

  variables {
    lxc_containers = {
      archon = {
        vmid       = 108
        hostname   = "archon"
        ip_address = "192.168.50.108"
        docker_compose = {
          path    = "/opt/archon/docker-compose.yml"
          content = "services:\n  app:\n    image: ghcr.io/jclee/archon:latest"
        }
        deploy = false
      }
    }

    mcp_host           = "192.168.50.112"
    deploy_lxc_configs = false
  }

  assert {
    condition = (
      try(output.lxc_configs.archon.vmid, 0) == 108 &&
      try(output.lxc_configs.archon.hostname, "") == "archon" &&
      try(output.lxc_configs.archon.ip_address, "") == "192.168.50.108" &&
      try(output.lxc_configs.archon.docker_compose, null) != null &&
      endswith(try(output.lxc_configs.archon.docker_compose, ""), "/configs/lxc-108-archon/docker-compose.yml")
    )
    error_message = "docker_compose output should include generated docker-compose path"
  }
}

run "test_container_without_services" {
  command = apply

  module {
    source = "../../../modules/proxmox/lxc-config"
  }

  variables {
    lxc_containers = {
      supabase = {
        vmid       = 107
        hostname   = "supabase"
        ip_address = "192.168.50.107"
        deploy     = false
      }
    }

    mcp_host           = "192.168.50.112"
    deploy_lxc_configs = false
  }

  assert {
    condition = (
      try(output.lxc_configs.supabase.vmid, 0) == 107 &&
      try(output.lxc_configs.supabase.hostname, "") == "supabase" &&
      try(output.lxc_configs.supabase.ip_address, "") == "192.168.50.107" &&
      length(try(output.lxc_configs.supabase.systemd_services, [])) == 0 &&
      length(try(output.lxc_configs.supabase.config_files, [])) == 0 &&
      output.service_count == 0
    )
    error_message = "container without services should have empty systemd_services list and service_count=0"
  }
}

run "test_docker_compose_null" {
  command = apply

  module {
    source = "../../../modules/proxmox/lxc-config"
  }

  variables {
    lxc_containers = {
      mcphub = {
        vmid       = 112
        hostname   = "mcphub"
        ip_address = "192.168.50.112"
        systemd_services = {
          mcp-sidecar = {
            description = "MCP sidecar"
            exec_start  = "/usr/local/bin/mcp-sidecar"
          }
        }
        deploy = false
      }
    }

    mcp_host           = "192.168.50.112"
    deploy_lxc_configs = false
  }

  assert {
    condition = (
      try(output.lxc_configs.mcphub.vmid, 0) == 112 &&
      try(output.lxc_configs.mcphub.docker_compose, "not-null") == null &&
      length(try(output.lxc_configs.mcphub.systemd_services, [])) == 1 &&
      output.service_count == 1
    )
    error_message = "container without docker_compose should return null docker_compose output"
  }
}

run "test_deploy_requires_ssh_key_when_enabled" {
  command = plan

  module {
    source = "../../../modules/proxmox/lxc-config"
  }

  variables {
    lxc_containers = {
      runner = {
        vmid       = 101
        hostname   = "runner"
        ip_address = "192.168.50.101"
        deploy     = false
      }
    }

    mcp_host           = "192.168.50.112"
    deploy_lxc_configs = true
    ssh_private_key    = ""
  }

  expect_failures = [
    check.deploy_requires_ssh_key,
  ]
}

run "test_deploy_with_ssh_key_passes_check" {
  command = plan

  module {
    source = "../../../modules/proxmox/lxc-config"
  }

  variables {
    lxc_containers = {
      runner = {
        vmid       = 101
        hostname   = "runner"
        ip_address = "192.168.50.101"
        deploy     = false
      }
    }

    mcp_host           = "192.168.50.112"
    deploy_lxc_configs = true
    ssh_private_key    = "mock-ssh-key-for-testing-only" # pragma: allowlist secret
  }

  assert {
    condition     = length(keys(output.lxc_configs)) == 1
    error_message = "deploy_lxc_configs=true with ssh_private_key should pass deploy_requires_ssh_key check"
  }
}
