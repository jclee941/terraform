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
      vmid           = module.hosts.hosts.youtube.vmid
      hostname       = "youtube"
      ip_address     = module.hosts.hosts.youtube.ip
      deploy         = var.deploy_vm_configs
      setup_filebeat = true

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
          # Google Cloud CLI
          "curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg",
          "echo 'deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main' | tee /etc/apt/sources.list.d/google-cloud-sdk.list",
          "apt-get update && apt-get install -y google-cloud-cli",
          # YouTube automation setup
          "mkdir -p /opt/youtube",
          "mkdir -p /opt/youtube/gcloud-config",
          "cd /opt/youtube && docker compose up -d",
        ]
        write_files = [
          {
            path        = "/etc/filebeat/filebeat.yml"
            content     = module.config_renderer.rendered_configs["youtube_filebeat"]
            permissions = "0644"
            owner       = "root:root"
          },
          {
            path        = "/opt/youtube/docker-compose.yml"
            content     = module.config_renderer.rendered_configs["youtube_docker_compose"]
            permissions = "0644"
            owner       = "root:root"
          },
          {
            path        = "/opt/youtube/.env"
            content     = module.config_renderer.rendered_configs["youtube_env"]
            permissions = "0600"
            owner       = "root:root"
          },
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
          "docker-compose-v2",
          "sshfs"
        ]
        runcmd = [
          "systemctl enable qemu-guest-agent",
          "systemctl start qemu-guest-agent",
          "systemctl enable docker",
          "systemctl start docker",
          "mkdir -p /opt/mcphub",
          "mkdir -p /opt/n8n",
          "mkdir -p /mnt/oc-dev /mnt/oc-kratos",
          "grep -q oc-dev /etc/fstab || echo 'jclee@${module.hosts.hosts["jclee-dev"].ip}:/home/jclee/dev /mnt/oc-dev fuse.sshfs _netdev,allow_other,default_permissions,IdentityFile=/root/.ssh/id_rsa,reconnect,ServerAliveInterval=15,ServerAliveCountMax=3 0 0' >> /etc/fstab",
          "grep -q oc-kratos /etc/fstab || echo 'jclee@${module.hosts.hosts["jclee-dev"].ip}:/home/jclee/.kratos /mnt/oc-kratos fuse.sshfs _netdev,allow_other,default_permissions,IdentityFile=/root/.ssh/id_rsa,reconnect,ServerAliveInterval=15,ServerAliveCountMax=3 0 0' >> /etc/fstab",
          "mountpoint -q /mnt/oc-dev || mount /mnt/oc-dev || true",
          "mountpoint -q /mnt/oc-kratos || mount /mnt/oc-kratos || true",
          "systemctl daemon-reload",
          "curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg",
          "echo 'deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main' > /etc/apt/sources.list.d/google-cloud-sdk.list",
          "apt-get update && apt-get install -y google-cloud-cli",
          "mkdir -p /opt/mcphub/gcloud-config",
          "mkdir -p /opt/mcphub/patches",
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
          },
          {
            path        = "/opt/mcphub/.gitconfig"
            content     = file("${path.module}/../112-mcphub/config/.gitconfig")
            permissions = "0644"
            owner       = "root:root"
          },
          {
            path        = "/opt/mcphub/patches/patch-placeholder.cjs"
            content     = file("${path.module}/../112-mcphub/config/patch-placeholder.cjs")
            permissions = "0644"
            owner       = "root:root"
          },
          {
            path        = "/opt/mcphub/patches/entrypoint-patch.sh"
            content     = file("${path.module}/../112-mcphub/config/entrypoint-patch.sh")
            permissions = "0755"
            owner       = "root:root"
          },
        ]
      }
    }
  }
}
