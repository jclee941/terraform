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
        runcmd = [
          "mkdir -p /etc/traefik/dynamic",
          "rm -f /etc/traefik/dynamic/gitlab.yml /etc/traefik/dynamic/gitlab-http.yml /etc/traefik/dynamic/archon.yml /etc/traefik/dynamic/supabase.yml /etc/traefik/dynamic/glitchtip.yml /etc/traefik/dynamic/bot.yml /etc/traefik/dynamic/opencode.yml /etc/traefik/dynamic/code.yml /etc/traefik/dynamic/vault.yml",
          "systemctl enable filebeat || true",
          "systemctl reload traefik || systemctl restart traefik || true",
        ]
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
        "middlewares.yml" = {
          path    = "/etc/traefik/dynamic/middlewares.yml"
          content = module.config_renderer.rendered_configs.traefik_middlewares
        }
        "registry.yml" = {
          path    = "/etc/traefik/dynamic/registry.yml"
          content = module.config_renderer.rendered_configs.traefik_registry
        }
        "mcphub.yml" = {
          path    = "/etc/traefik/dynamic/mcphub.yml"
          content = module.config_renderer.rendered_configs.traefik_mcphub
        }
        "n8n.yml" = {
          path    = "/etc/traefik/dynamic/n8n.yml"
          content = module.config_renderer.rendered_configs.traefik_n8n
        }
        "nas.yml" = {
          path    = "/etc/traefik/dynamic/nas.yml"
          content = module.config_renderer.rendered_configs.traefik_nas
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
        packages = ["curl", "jq", "ca-certificates", "nfs-common"]
        runcmd = [
          "mkdir -p /mnt/nas-elk",
          "mountpoint -q /mnt/nas-elk || mount -t nfs -o vers=3,nolock,rw,hard,noatime ${module.hosts.hosts.synology.ip}:/volume1/shared/elk-snapshots /mnt/nas-elk || true",
          "grep -q '/mnt/nas-elk' /etc/fstab || echo '${module.hosts.hosts.synology.ip}:/volume1/shared/elk-snapshots /mnt/nas-elk nfs vers=3,nolock,rw,hard,noatime,_netdev,x-systemd.automount 0 0' >> /etc/fstab",
          "systemctl enable filebeat || true",
        ]
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
      hostname       = "cliproxy"
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
