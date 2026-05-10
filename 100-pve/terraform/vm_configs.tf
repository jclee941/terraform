# =============================================================================
# VM CONFIG DEPLOYMENT
# =============================================================================

module "vm_config" {
  source = "../../modules/proxmox/vm-config"

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
          "docker.io",
          "docker-compose-v2",
          "fail2ban",
        ]
        runcmd = [
          "systemctl enable qemu-guest-agent",
          "systemctl start qemu-guest-agent",
          "systemctl enable docker",
          "systemctl start docker",
          "# SSH hardening",
          "sed -i 's/^#\\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config",
          "sed -i 's/^#\\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config",
          "systemctl restart sshd",
          "# fail2ban SSH jail",
          "printf '[sshd]\\nenabled = true\\nport = ssh\\nfilter = sshd\\nmaxretry = 5\\nbantime = 3600\\n' > /etc/fail2ban/jail.d/sshd.conf",
          "systemctl enable fail2ban",
          "systemctl start fail2ban",
          "# Google Cloud CLI",
          "curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg",
          "echo 'deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main' | tee /etc/apt/sources.list.d/google-cloud-sdk.list",
          "apt-get update && apt-get install -y google-cloud-cli",
          "# YouTube automation setup",
          "mkdir -p /opt/youtube/gcloud-config",
          "cd /opt/youtube && docker compose up -d || true",
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
          {
            path        = "/etc/profile.d/docker-buildx-s3.sh"
            content     = <<-EOF
              # Docker Buildx S3 cache environment variables for MinIO
              export BUILDKIT_S3_REGION=us-east-1
              export BUILDKIT_S3_BUCKET=buildx-cache
              export BUILDKIT_S3_ENDPOINT=http://192.168.50.215:9000
              export BUILDKIT_S3_ACCESS_KEY_ID=minioadmin
              export BUILDKIT_S3_SECRET_ACCESS_KEY=minioadmin
            EOF
            permissions = "0644"
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
          "sshfs",
          "fail2ban",
        ]
        runcmd = [
          "systemctl enable qemu-guest-agent",
          "systemctl start qemu-guest-agent",
          "systemctl enable docker",
          "systemctl start docker",
          "# SSH hardening",
          "sed -i 's/^#\\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config",
          "sed -i 's/^#\\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config",
          "systemctl restart sshd",
          "# fail2ban SSH jail",
          "printf '[sshd]\\nenabled = true\\nport = ssh\\nfilter = sshd\\nmaxretry = 5\\nbantime = 3600\\n' > /etc/fail2ban/jail.d/sshd.conf",
          "systemctl enable fail2ban",
          "systemctl start fail2ban",
          "mkdir -p /opt/mcphub",
          "mkdir -p /mnt/oc-home",
          "grep -q oc-home /etc/fstab || echo 'jclee@${module.hosts.hosts["jclee-dev"].ip}:/home/jclee /mnt/oc-home fuse.sshfs _netdev,allow_other,default_permissions,IdentityFile=/root/.ssh/id_rsa,reconnect,ServerAliveInterval=15,ServerAliveCountMax=3 0 0' >> /etc/fstab",
          "mountpoint -q /mnt/oc-home || mount /mnt/oc-home || true",
          "systemctl daemon-reload",
          "curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg",
          "echo 'deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main' > /etc/apt/sources.list.d/google-cloud-sdk.list",
          "apt-get update && apt-get install -y google-cloud-cli",
          "mkdir -p /opt/mcphub/gcloud-config",
          "mkdir -p /opt/mcphub/patches",
          "cd /opt/mcphub && docker compose build && docker compose up -d",
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
            content     = file("${path.module}/../../112-mcphub/Dockerfile.proxmox")
            permissions = "0644"
            owner       = "root:root"
          },
          {
            path        = "/opt/mcphub/Dockerfile.playwright"
            content     = file("${path.module}/../../112-mcphub/Dockerfile.playwright")
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
            path        = "/opt/mcphub/.gitconfig"
            content     = file("${path.module}/../../112-mcphub/config/.gitconfig")
            permissions = "0644"
            owner       = "root:root"
          },
          {
            path        = "/opt/mcphub/patches/patch-placeholder.cjs"
            content     = file("${path.module}/../../112-mcphub/config/patch-placeholder.cjs")
            permissions = "0644"
            owner       = "root:root"
          },
          {
            path        = "/opt/mcphub/patches/entrypoint-patch"
            content     = filebase64("${path.module}/../../112-mcphub/config/entrypoint-patch")
            permissions = "0755"
            owner       = "root:root"
            encoding    = "base64"
          },
        ]
      }
    }

    jclee-dev = {
      vmid           = module.hosts.hosts["jclee-dev"].vmid
      hostname       = "oc"
      ip_address     = module.hosts.hosts["jclee-dev"].ip
      deploy         = var.deploy_vm_configs
      setup_filebeat = false

      cloud_init = {
        packages = [
          "qemu-guest-agent",
          "docker.io",
          "docker-compose-v2",
          "fail2ban",
        ]
        runcmd = [
          "systemctl enable qemu-guest-agent",
          "systemctl start qemu-guest-agent",
          "systemctl enable docker",
          "systemctl start docker",
          "# SSH hardening",
          "sed -i 's/^#\\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config",
          "sed -i 's/^#\\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config",
          "systemctl restart sshd",
          "# fail2ban SSH jail",
          "printf '[sshd]\\nenabled = true\\nport = ssh\\nfilter = sshd\\nmaxretry = 5\\nbantime = 3600\\n' > /etc/fail2ban/jail.d/sshd.conf",
          "systemctl enable fail2ban",
          "systemctl start fail2ban",
          "# Docker Buildx S3 cache setup via MinIO (192.168.50.215:9000)",
          "mkdir -p /etc/docker/buildx",
          "docker buildx create --use --name s3-cache --driver docker-container --driver-opt env.BUILDKIT_S3_REGION=us-east-1 --driver-opt env.BUILDKIT_S3_BUCKET=buildx-cache --driver-opt env.BUILDKIT_S3_ENDPOINT=http://192.168.50.215:9000 --driver-opt env.BUILDKIT_S3_ACCESS_KEY_ID=minioadmin --driver-opt env.BUILDKIT_S3_SECRET_ACCESS_KEY=minioadmin || docker buildx use s3-cache || true",
          "docker buildx inspect s3-cache --bootstrap || true",
        ]
        write_files = [
          {
            path        = "/etc/profile.d/docker-buildx-s3.sh"
            content     = <<-EOF
              # Docker Buildx S3 cache environment variables for MinIO
              export BUILDKIT_S3_REGION=us-east-1
              export BUILDKIT_S3_BUCKET=buildx-cache
              export BUILDKIT_S3_ENDPOINT=http://192.168.50.215:9000
              export BUILDKIT_S3_ACCESS_KEY_ID=minioadmin
              export BUILDKIT_S3_SECRET_ACCESS_KEY=minioadmin
            EOF
            permissions = "0644"
            owner       = "root:root"
          },
        ]
      }
    }
  }
}
