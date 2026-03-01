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
