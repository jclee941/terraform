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
        "traefik-middlewares.yml" = {
          path    = "/etc/traefik/dynamic/middlewares.yml"
          content = module.config_renderer.rendered_configs.traefik_middlewares
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

    n8n = {
      vmid           = module.hosts.hosts.n8n.vmid
      hostname       = "n8n"
      ip_address     = module.hosts.hosts.n8n.ip
      deploy         = var.deploy_lxc_configs
      setup_filebeat = true

      docker_compose = {
        path    = "/opt/n8n/docker-compose.yml"
        content = module.config_renderer.rendered_configs.n8n_docker_compose
      }

      config_files = {
        "n8n.env" = {
          path    = "/opt/n8n/n8n.env"
          content = module.config_renderer.rendered_configs.n8n_env
        }
        "Dockerfile.n8n" = {
          path    = "/opt/n8n/Dockerfile.n8n"
          content = file("${path.module}/../110-n8n/Dockerfile.n8n")
        }
        "patches-license.js" = {
          path    = "/opt/n8n/patches/license.js"
          content = file("${path.module}/../110-n8n/patches/n8n/license.js")
        }
        "patches-license-state.js" = {
          path    = "/opt/n8n/patches/license-state.js"
          content = file("${path.module}/../110-n8n/patches/n8n/license-state.js")
        }
        "filebeat.yml" = {
          path    = "/etc/filebeat/filebeat.yml"
          content = module.config_renderer.rendered_configs.n8n_filebeat
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
