provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = local.effective_proxmox_api_token
  insecure  = var.proxmox_insecure
}

provider "onepassword" {}

# =============================================================================
# HOST INVENTORY (Single Source of Truth)
# =============================================================================

module "hosts" {
  source = "./envs/prod"
}

# env-config module removed — non-hosts template vars inlined below
# All IP/port refs now use hosts.X.Y directly in templates

# =============================================================================
# CONTAINER MODULES
# =============================================================================

module "lxc" {
  source   = "../modules/proxmox/lxc"
  for_each = local.containers

  node_name        = local.node_name
  vmid             = each.value.vmid
  hostname         = each.value.hostname
  ip_address       = each.value.ip
  memory           = each.value.memory
  swap             = each.value.swap
  cores            = each.value.cores
  disk_size        = each.value.disk_size
  description      = each.value.description
  privileged       = lookup(each.value, "privileged", false)
  network_gateway  = var.network_gateway
  dns_servers      = var.dns_servers
  datastore_id     = var.datastore_id
  managed_vmid_min = var.managed_vmid_range.min
  managed_vmid_max = var.managed_vmid_range.max
  ssh_public_keys  = var.ssh_public_keys
}

# =============================================================================
# VIRTUAL MACHINES (VMs)
# =============================================================================

module "vm" {
  source   = "../modules/proxmox/vm"
  for_each = local.vm_definitions

  node_name        = local.node_name
  vmid             = each.value.vmid
  hostname         = each.key
  description      = each.value.description
  ip_address       = module.hosts.hosts[each.key].ip
  memory           = each.value.memory
  cores            = each.value.cores
  disk_size        = each.value.disk_size
  bios             = try(each.value.bios, "seabios")
  machine          = try(each.value.machine, "pc")
  network_gateway  = var.network_gateway
  dns_servers      = var.dns_servers
  datastore_id     = var.datastore_id
  managed_vmid_min = var.managed_vmid_range.min
  managed_vmid_max = var.managed_vmid_range.max
  hostpci_devices  = try(each.value.hostpci_devices, [])

  cloud_init_file_id = try(local.cloud_init_files[each.key], null)
}

moved {
  from = proxmox_virtual_environment_vm.mcphub
  to   = module.vm["mcphub"].proxmox_virtual_environment_vm.this
}

# =============================================================================
# VM CONFIG DEPLOYMENT
# =============================================================================

module "vm_config" {
  source = "../modules/proxmox/vm-config"

  deploy_vm_configs = var.deploy_vm_configs
  ssh_user          = "root"
  ssh_private_key   = lookup(module.onepassword_secrets.secrets, "proxmox_ssh_private_key", "")

  vms = {
    youtube = {
      vmid       = module.hosts.hosts.youtube.vmid
      hostname   = "youtube"
      ip_address = module.hosts.hosts.youtube.ip
      deploy     = var.deploy_vm_configs

      cloud_init = {
        packages = [
          "qemu-guest-agent",
          "curl",
          "vim",
          "git",
          "gnupg",
        ]
        runcmd = [
          "systemctl enable qemu-guest-agent",
          "systemctl start qemu-guest-agent",
        ]
      }
    }

    mcphub = {
      vmid           = module.hosts.hosts.mcphub.vmid
      hostname       = "mcphub"
      ip_address     = module.hosts.hosts.mcphub.ip
      deploy         = var.deploy_vm_configs
      setup_filebeat = true

      cloud_init = {
        packages = [
          "qemu-guest-agent",
          "curl",
          "vim",
          "git",
          "htop",
          "docker.io",
          "docker-compose-v2"
        ]
        runcmd = [
          "systemctl enable qemu-guest-agent",
          "systemctl start qemu-guest-agent",
          "systemctl enable docker",
          "systemctl start docker",
          "mkdir -p /opt/mcphub",
          "mkdir -p /opt/n8n",
          "systemctl daemon-reload",
          "cd /opt/mcphub && docker compose build && docker compose up -d",
          "cd /opt/n8n && docker compose up -d"
        ]
        write_files = [
          {
            path        = "/opt/mcphub/docker-compose.yml"
            content     = module.config_renderer.rendered_configs["mcphub_docker_compose"]
            permissions = "0644"
            owner       = "root:root"
          },
          {
            path        = "/opt/mcphub/mcp_settings.json"
            content     = module.config_renderer.rendered_configs["mcphub_mcp_settings"]
            permissions = "0644"
            owner       = "root:root"
          },
          {
            path        = "/opt/mcphub/Dockerfile.proxmox"
            content     = file("${path.module}/../112-mcphub/Dockerfile.proxmox")
            permissions = "0644"
            owner       = "root:root"
          },
          {
            path        = "/opt/mcphub/Dockerfile.playwright"
            content     = file("${path.module}/../112-mcphub/Dockerfile.playwright")
            permissions = "0644"
            owner       = "root:root"
          },
          {
            path        = "/opt/mcphub/.env"
            content     = module.config_renderer.rendered_configs["mcphub_env"]
            permissions = "0600"
            owner       = "root:root"
          },
          {
            path        = "/etc/filebeat/filebeat.yml"
            content     = module.config_renderer.rendered_configs["mcphub_filebeat"]
            permissions = "0644"
            owner       = "root:root"
          },
          {
            path        = "/opt/n8n/docker-compose.yml"
            content     = module.config_renderer.rendered_configs["mcphub_n8n_docker_compose"]
            permissions = "0644"
            owner       = "root:root"
          }
        ]
      }
    }
  }
}

# =============================================================================
# LXC CONFIG DEPLOYMENT
# =============================================================================

module "lxc_config" {
  source = "../modules/proxmox/lxc-config"

  deploy_lxc_configs = var.deploy_lxc_configs
  mcp_host           = module.hosts.hosts.mcphub.ip
  ssh_user           = "root"
  ssh_private_key    = lookup(module.onepassword_secrets.secrets, "proxmox_ssh_private_key", "")

  lxc_containers = {
    runner = {
      vmid           = module.hosts.hosts.runner.vmid
      hostname       = "runner"
      ip_address     = module.hosts.hosts.runner.ip
      deploy         = var.deploy_lxc_configs
      setup_filebeat = true

      config_files = {
        "filebeat.yml" = {
          path    = "/etc/filebeat/filebeat.yml"
          content = module.config_renderer.rendered_configs.runner_filebeat
        }
      }
    }

    traefik = {
      vmid           = module.hosts.hosts.traefik.vmid
      hostname       = "traefik"
      ip_address     = module.hosts.hosts.traefik.ip
      deploy         = var.deploy_lxc_configs
      setup_filebeat = true

      config_files = {
        "traefik.yml" = {
          path    = "/etc/traefik/traefik.yml"
          content = file("${path.module}/../102-traefik/config/traefik.yml")
        }
        "traefik-elk.yml" = {
          path    = "/etc/traefik/dynamic/elk.yml"
          content = module.config_renderer.rendered_configs.traefik_elk
        }
        "traefik-glitchtip.yml" = {
          path    = "/etc/traefik/dynamic/glitchtip.yml"
          content = module.config_renderer.rendered_configs.traefik_glitchtip
        }
        "traefik-mcphub.yml" = {
          path    = "/etc/traefik/dynamic/mcphub.yml"
          content = module.config_renderer.rendered_configs.traefik_mcphub
        }
        "traefik-n8n.yml" = {
          path    = "/etc/traefik/dynamic/n8n.yml"
          content = module.config_renderer.rendered_configs.traefik_n8n
        }
        "traefik-synology.yml" = {
          path    = "/etc/traefik/dynamic/synology.yml"
          content = module.config_renderer.rendered_configs.traefik_synology
        }
        "traefik-archon.yml" = {
          path    = "/etc/traefik/dynamic/archon.yml"
          content = module.config_renderer.rendered_configs.traefik_archon
        }
        "traefik-grafana.yml" = {
          path    = "/etc/traefik/dynamic/grafana.yml"
          content = module.config_renderer.rendered_configs.traefik_grafana
        }
        "traefik-nas.yml" = {
          path    = "/etc/traefik/dynamic/nas.yml"
          content = module.config_renderer.rendered_configs.traefik_nas
        }
        "traefik-opencode.yml" = {
          path    = "/etc/traefik/dynamic/opencode.yml"
          content = module.config_renderer.rendered_configs.traefik_opencode
        }
        "traefik-supabase.yml" = {
          path    = "/etc/traefik/dynamic/supabase.yml"
          content = module.config_renderer.rendered_configs.traefik_supabase
        }
        "filebeat.yml" = {
          path    = "/etc/filebeat/filebeat.yml"
          content = module.config_renderer.rendered_configs.traefik_filebeat
        }
        "cloudflared-docker-compose.yml" = {
          path    = "/opt/cloudflared/docker-compose.yml"
          content = module.config_renderer.rendered_configs.traefik_cloudflared
        }
      }
    }

    grafana = {
      vmid           = module.hosts.hosts.grafana.vmid
      hostname       = "grafana"
      ip_address     = module.hosts.hosts.grafana.ip
      deploy         = var.deploy_lxc_configs
      setup_filebeat = true

      config_files = {
        "prometheus.yml" = {
          path    = "/etc/prometheus/prometheus.yml"
          content = module.config_renderer.rendered_configs.prometheus
        }
        "grafana-datasources.yml" = {
          path    = "/etc/grafana/provisioning/datasources/datasources.yml"
          content = module.config_renderer.rendered_configs.grafana_datasources
        }
        "filebeat.yml" = {
          path    = "/etc/filebeat/filebeat.yml"
          content = module.config_renderer.rendered_configs.grafana_filebeat
        }
      }

      systemd_services = {
        prometheus = {
          description = "Prometheus Monitoring"
          exec_start  = "/usr/bin/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/var/lib/prometheus --web.listen-address=0.0.0.0:9090"
          user        = "prometheus"
          restart     = "always"
          restart_sec = 5
        }
      }
    }

    elk = {
      vmid           = module.hosts.hosts.elk.vmid
      hostname       = "elk"
      ip_address     = module.hosts.hosts.elk.ip
      deploy         = var.deploy_lxc_configs
      setup_filebeat = true

      docker_compose = {
        path    = "/opt/elk/docker-compose.yml"
        content = module.config_renderer.rendered_configs.elk_docker_compose
      }

      config_files = {
        "logstash.conf" = {
          path    = "/opt/elk/config/logstash.conf"
          content = module.config_renderer.rendered_configs.elk_logstash_conf
        }
        "logstash.yml" = {
          path    = "/opt/elk/config/logstash.yml"
          content = module.config_renderer.rendered_configs.elk_logstash_yml
        }
        "ilm-policy.json" = {
          path    = "/opt/elk/config/ilm-policy.json"
          content = module.config_renderer.rendered_configs.elk_ilm_policy
        }
        "setup-ilm.sh" = {
          path    = "/opt/elk/scripts/setup-ilm.sh"
          content = module.config_renderer.rendered_configs.elk_setup_ilm
        }
        "filebeat.yml" = {
          path    = "/etc/filebeat/filebeat.yml"
          content = module.config_renderer.rendered_configs.elk_filebeat
        }
        "Dockerfile.logstash" = {
          path    = "/opt/elk/config/Dockerfile.logstash"
          content = module.config_renderer.rendered_configs.elk_dockerfile_logstash
        }
      }
    }

    glitchtip = {
      vmid           = module.hosts.hosts.glitchtip.vmid
      hostname       = "glitchtip"
      ip_address     = module.hosts.hosts.glitchtip.ip
      deploy         = var.deploy_lxc_configs
      setup_filebeat = true

      docker_compose = {
        path    = "/opt/glitchtip/docker-compose.yml"
        content = module.config_renderer.rendered_configs.glitchtip_docker_compose
      }

      config_files = {
        "glitchtip.env" = {
          path    = "/opt/glitchtip/glitchtip.env"
          content = module.config_renderer.rendered_configs.glitchtip_env
        }
        "filebeat.yml" = {
          path    = "/etc/filebeat/filebeat.yml"
          content = module.config_renderer.rendered_configs.glitchtip_filebeat
        }
      }
    }

    supabase = {
      vmid           = module.hosts.hosts.supabase.vmid
      hostname       = "supabase"
      ip_address     = module.hosts.hosts.supabase.ip
      deploy         = var.deploy_lxc_configs
      setup_filebeat = true

      docker_compose = {
        path    = "/opt/supabase/docker-compose.yml"
        content = module.config_renderer.rendered_configs.supabase_docker_compose
      }

      config_files = {
        "supabase.env" = {
          path    = "/opt/supabase/.env"
          content = module.config_renderer.rendered_configs.supabase_env
        }
        "filebeat.yml" = {
          path    = "/etc/filebeat/filebeat.yml"
          content = module.config_renderer.rendered_configs.supabase_filebeat
        }
      }
    }

    archon = {
      vmid           = module.hosts.hosts.archon.vmid
      hostname       = "archon"
      ip_address     = module.hosts.hosts.archon.ip
      deploy         = var.deploy_lxc_configs
      setup_filebeat = true

      docker_compose = {
        path    = "/opt/archon/docker-compose.yml"
        content = module.config_renderer.rendered_configs.archon_docker_compose
      }

      config_files = {
        "archon.env" = {
          path    = "/opt/archon/.env"
          content = module.config_renderer.rendered_configs.archon_env
        }
        "filebeat.yml" = {
          path    = "/etc/filebeat/filebeat.yml"
          content = module.config_renderer.rendered_configs.archon_filebeat
        }
      }
    }

    coredns = {
      vmid           = module.hosts.hosts.coredns.vmid
      hostname       = "coredns"
      ip_address     = module.hosts.hosts.coredns.ip
      deploy         = var.deploy_lxc_configs
      setup_filebeat = true

      docker_compose = {
        path    = "/opt/coredns/docker-compose.yml"
        content = module.config_renderer.rendered_configs.coredns_docker_compose
      }

      config_files = {
        "Corefile" = {
          path    = "/opt/coredns/Corefile"
          content = module.config_renderer.rendered_configs.coredns_corefile
        }
        "filebeat.yml" = {
          path    = "/etc/filebeat/filebeat.yml"
          content = module.config_renderer.rendered_configs.coredns_filebeat
        }
      }
    }
  }
}

# =============================================================================
# 1PASSWORD SECRETS
# =============================================================================

module "onepassword_secrets" {
  source     = "../modules/shared/onepassword-secrets"
  vault_name = var.onepassword_vault_name
}

# =============================================================================
# CONFIG RENDERER - Centralized Config Generation
# =============================================================================

module "config_renderer" {
  source = "../modules/proxmox/config-renderer"

  template_vars = merge(
    module.onepassword_secrets.secrets,
    module.onepassword_secrets.metadata,
    {
      hosts                = module.hosts.hosts
      domain               = "jclee.me"
      network_cidr         = var.network_cidr
      github_org           = var.github_org
      infrastructure_nodes = local.infrastructure_nodes

      elk_version = "8.17.0"

      glitchtip_version          = "v6.0.5"
      glitchtip_postgres_version = "15.16-alpine"
      glitchtip_redis_version    = "7.4.7-alpine"
      mcphub_version             = "0.12.3"

      es_heap                     = "3g"
      logstash_heap               = "1g"
      logstash_dlq_size           = "1024mb"
      elasticsearch_index_pattern = "logs-%%{[service]}-%%{+YYYY.MM.dd}"
      ilm_delete_after            = "30d"
      ilm_policy_name             = "homelab-logs-30d"
      ilm_critical_delete_after   = "90d"
      ilm_ephemeral_delete_after  = "7d"

      prometheus_datasource_uid = "prometheus"
      sla_target_percentage     = "99.9"

      mcp_catalog_json           = jsonencode(local.mcp_catalog)
      mcp_hub_servers_json       = jsonencode(local.mcp_hub_servers)
      mcp_hub_stdio_json         = jsonencode(local.mcp_hub_stdio_servers)
      mcp_hub_sse_json           = jsonencode(local.mcp_hub_sse_servers)
      mcp_hub_external_sse_json  = jsonencode(local.mcp_hub_external_sse_servers)
      mcp_hub_http_json          = jsonencode(local.mcp_hub_http_servers)
      mcp_hub_external_http_json = jsonencode(local.mcp_hub_external_http_servers)
      mcp_host                   = local.mcp_catalog.mcp_host
      proxmox_host               = local.proxmox_host
      proxmox_port               = local.proxmox_port
      proxmox_ssl_mode           = local.proxmox_ssl_mode
      homelab_tunnel_token       = local.effective_homelab_tunnel_token
    }
  )
  output_dir = "${path.module}/configs/rendered"

  template_files = merge(
    local.root_templates,
    local.service_templates,
  )
}
