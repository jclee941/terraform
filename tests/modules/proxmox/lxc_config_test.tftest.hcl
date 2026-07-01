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
      coredns = {
        vmid       = 103
        hostname   = "coredns"
        ip_address = "192.168.50.103"
        deploy     = false
      }
    }

    deploy_lxc_configs = false
  }

  assert {
    condition = (
      length(keys(output.lxc_configs)) == 2 &&
      contains(keys(output.lxc_configs), "traefik") &&
      contains(keys(output.lxc_configs), "coredns") &&
      try(output.lxc_configs.traefik.vmid, 0) == 102 &&
      try(output.lxc_configs.traefik.hostname, "") == "traefik" &&
      try(output.lxc_configs.traefik.ip_address, "") == "192.168.50.102" &&
      try(output.lxc_configs.coredns.vmid, 0) == 103 &&
      try(output.lxc_configs.coredns.hostname, "") == "coredns" &&
      try(output.lxc_configs.coredns.ip_address, "") == "192.168.50.103" &&
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
      coredns = {
        vmid       = 103
        hostname   = "coredns"
        ip_address = "192.168.50.103"
        systemd_services = {
          coredns = {
            description = "CoreDNS service"
            exec_start  = "/usr/local/bin/coredns"
          }
          dns-health = {
            description = "DNS health probe"
            exec_start  = "/usr/local/bin/dns-health"
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

    deploy_lxc_configs = false
  }

  assert {
    condition = (
      output.service_count == 4 &&
      length(try(output.lxc_configs.runner.systemd_services, [])) == 1 &&
      length(try(output.lxc_configs.coredns.systemd_services, [])) == 2 &&
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
      mcphub = {
        vmid       = 112
        hostname   = "mcphub"
        ip_address = "192.168.50.112"
        docker_compose = {
          path    = "/opt/mcphub/docker-compose.yml"
          content = "services:\n  app:\n    image: ghcr.io/jclee/mcphub:latest"
        }
        deploy = false
      }
    }

    deploy_lxc_configs = false
  }

  assert {
    condition = (
      try(output.lxc_configs.mcphub.vmid, 0) == 112 &&
      try(output.lxc_configs.mcphub.hostname, "") == "mcphub" &&
      try(output.lxc_configs.mcphub.ip_address, "") == "192.168.50.112" &&
      try(output.lxc_configs.mcphub.docker_compose, null) != null &&
      endswith(try(output.lxc_configs.mcphub.docker_compose, ""), "/configs/lxc-112-mcphub/docker-compose.yml")
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
      coredns = {
        vmid       = 103
        hostname   = "coredns"
        ip_address = "192.168.50.103"
        deploy     = false
      }
    }

    deploy_lxc_configs = false
  }

  assert {
    condition = (
      try(output.lxc_configs.coredns.vmid, 0) == 103 &&
      try(output.lxc_configs.coredns.hostname, "") == "coredns" &&
      try(output.lxc_configs.coredns.ip_address, "") == "192.168.50.103" &&
      length(try(output.lxc_configs.coredns.systemd_services, [])) == 0 &&
      length(try(output.lxc_configs.coredns.config_files, [])) == 0 &&
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

    deploy_lxc_configs = true
    ssh_private_key    = "mock-ssh-key-for-testing-only" # pragma: allowlist secret
  }

  assert {
    condition     = length(keys(output.lxc_configs)) == 1
    error_message = "deploy_lxc_configs=true with ssh_private_key should pass deploy_requires_ssh_key check"
  }
}
