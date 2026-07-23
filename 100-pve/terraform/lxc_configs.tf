# =============================================================================
# LXC CONFIG DEPLOYMENT
# =============================================================================

module "lxc_config" {
  source = "../../modules/proxmox/lxc-config"

  deploy_lxc_configs = var.deploy_lxc_configs
  ssh_user           = "root"
  ssh_private_key    = lookup(module.onepassword_secrets.secrets, "proxmox_ssh_private_key", "")

  lxc_containers = {
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
  }
}
