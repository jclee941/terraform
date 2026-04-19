# =============================================================================
# LXC CONFIG DEPLOYMENT
# =============================================================================

module "lxc_config" {
  source = "../../modules/proxmox/lxc-config"

  deploy_lxc_configs = var.deploy_lxc_configs
  mcp_host           = module.hosts.hosts.mcphub.ip
  ssh_user           = "root"
  ssh_private_key    = lookup(module.onepassword_secrets.secrets, "proxmox_ssh_private_key", "")

  lxc_containers = {
    runner = {
      vmid           = module.hosts.hosts["runner"].vmid
      hostname       = "runner"
      ip_address     = module.hosts.hosts["runner"].ip
      deploy         = var.deploy_lxc_configs
      setup_filebeat = true

      cloud_init = {
        packages = ["curl", "jq", "ca-certificates"]
        runcmd   = ["systemctl enable filebeat || true"]
      }

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

      cloud_init = {
        packages = ["curl", "jq", "ca-certificates"]
        runcmd   = ["systemctl enable filebeat || true"]
      }

      config_files = {
        "traefik.yml" = {
          path    = "/etc/traefik/traefik.yml"
          content = file("${path.module}/../../102-traefik/config/traefik.yml")
        }
        "filebeat.yml" = {
          path    = "/etc/filebeat/filebeat.yml"
          content = module.config_renderer.rendered_configs.traefik_filebeat
        }
      }
    }

    elk = {
      vmid           = module.hosts.hosts.elk.vmid
      hostname       = "elk"
      ip_address     = module.hosts.hosts.elk.ip
      deploy         = var.deploy_lxc_configs
      setup_filebeat = true

      cloud_init = {
        packages = ["curl", "jq", "ca-certificates"]
        runcmd   = ["systemctl enable filebeat || true"]
      }

      docker_compose = {
        path    = "/opt/elk/docker-compose.yml"
        content = module.config_renderer.rendered_configs.elk_docker_compose
      }

      config_files = {
        "filebeat.yml" = {
          path    = "/etc/filebeat/filebeat.yml"
          content = module.config_renderer.rendered_configs.elk_filebeat
        }
      }
    }

    n8n = {
      vmid           = module.hosts.hosts.n8n.vmid
      hostname       = "n8n"
      ip_address     = module.hosts.hosts.n8n.ip
      deploy         = var.deploy_lxc_configs
      setup_filebeat = true

      cloud_init = {
        packages = ["curl", "jq", "ca-certificates"]
        runcmd   = ["systemctl enable filebeat || true"]
      }

      docker_compose = {
        path    = "/opt/n8n/docker-compose.yml"
        content = module.config_renderer.rendered_configs.n8n_docker_compose
      }

      config_files = {
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

      cloud_init = {
        packages = ["curl", "jq", "ca-certificates"]
        runcmd   = ["systemctl enable filebeat || true"]
      }

      docker_compose = {
        path    = "/opt/supabase/docker-compose.yml"
        content = module.config_renderer.rendered_configs.supabase_docker_compose
      }

      config_files = {
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

      cloud_init = {
        packages = ["curl", "jq", "ca-certificates"]
        runcmd   = ["systemctl enable filebeat || true"]
      }

      docker_compose = {
        path    = "/opt/archon/docker-compose.yml"
        content = module.config_renderer.rendered_configs.archon_docker_compose
      }

      config_files = {
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

      cloud_init = {
        packages = ["curl", "jq", "ca-certificates"]
        runcmd   = ["systemctl enable filebeat || true"]
      }

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

    cliproxy = {
      vmid           = module.hosts.hosts["cliproxy"].vmid
      hostname       = "proxy"
      ip_address     = module.hosts.hosts["cliproxy"].ip
      deploy         = var.deploy_lxc_configs
      setup_filebeat = false

      cloud_init = {
        packages = ["curl", "squid"]
        runcmd   = ["systemctl enable squid || true"]
      }

      config_files = {}
    }
  }
}
