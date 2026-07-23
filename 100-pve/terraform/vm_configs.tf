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
        runcmd = concat(local.vm_baseline_runcmd, [
          "# Google Cloud CLI",
          "curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg",
          "echo 'deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main' | tee /etc/apt/sources.list.d/google-cloud-sdk.list",
          "apt-get update && apt-get install -y google-cloud-cli",
          "# YouTube automation setup",
          "mkdir -p /opt/youtube/gcloud-config",
          "cd /opt/youtube && docker compose up -d || true",
        ])
        write_files = [
          merge(local.vm_filebeat_write_file_defaults, {
            content = module.config_renderer.rendered_configs["youtube_filebeat"]
          }),
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
              export BUILDKIT_S3_ACCESS_KEY_ID=${module.onepassword_secrets.secrets["registry_minio_user"]}
              export BUILDKIT_S3_SECRET_ACCESS_KEY=${module.onepassword_secrets.secrets["registry_minio_password"]}
            EOF
            permissions = "0644"
            owner       = "root:root"
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
        runcmd = concat(local.vm_baseline_runcmd, [
          "# Docker Buildx S3 cache setup via MinIO (192.168.50.215:9000)",
          "mkdir -p /etc/docker/buildx",
          "docker buildx create --use --name s3-cache --driver docker-container --driver-opt env.BUILDKIT_S3_REGION=us-east-1 --driver-opt env.BUILDKIT_S3_BUCKET=buildx-cache --driver-opt env.BUILDKIT_S3_ENDPOINT=http://192.168.50.215:9000 --driver-opt env.BUILDKIT_S3_ACCESS_KEY_ID=${module.onepassword_secrets.secrets["registry_minio_user"]} --driver-opt env.BUILDKIT_S3_SECRET_ACCESS_KEY=${module.onepassword_secrets.secrets["registry_minio_password"]} || docker buildx use s3-cache || true",
          "docker buildx inspect s3-cache --bootstrap || true",
        ])
        write_files = [
          {
            path        = "/etc/profile.d/docker-buildx-s3.sh"
            content     = <<-EOF
              # Docker Buildx S3 cache environment variables for MinIO
              export BUILDKIT_S3_REGION=us-east-1
              export BUILDKIT_S3_BUCKET=buildx-cache
              export BUILDKIT_S3_ENDPOINT=http://192.168.50.215:9000
              export BUILDKIT_S3_ACCESS_KEY_ID=${module.onepassword_secrets.secrets["registry_minio_user"]}
              export BUILDKIT_S3_SECRET_ACCESS_KEY=${module.onepassword_secrets.secrets["registry_minio_password"]}
            EOF
            permissions = "0644"
            owner       = "root:root"
          },
        ]
      }
    }
  }
}
