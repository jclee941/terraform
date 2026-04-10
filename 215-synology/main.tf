# -----------------------------------------------------------------------------
# Providers
# -----------------------------------------------------------------------------

provider "synology" {
  host            = var.synology_host
  user            = local.effective_synology_user
  password        = local.effective_synology_password
  skip_cert_check = var.synology_skip_cert_check
}

provider "onepassword" {}

locals {
  _registry_config = var.enable_gitlab_registry ? [
    "registry_external_url '${var.gitlab_registry_external_url}'",
    "registry['enable'] = true",
    "registry_nginx['enable'] = true",
    "registry_nginx['listen_port'] = ${var.gitlab_registry_port}",
  ] : []

  gitlab_omnibus_config = join("\n", concat([
    "external_url '${var.gitlab_external_url}'",
  ], local._registry_config))
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "synology_core_network" "this" {}

# -----------------------------------------------------------------------------
# Core Packages — ensure required DSM packages are installed
# -----------------------------------------------------------------------------

resource "synology_core_package" "container_manager" {
  for_each = var.enable_container_manager_package ? { container_manager = true } : {}

  name = "ContainerManager"
}

resource "synology_container_project" "gitlab" {
  for_each = var.enable_gitlab_project ? { gitlab = true } : {}

  name       = "gitlab"
  share_path = var.gitlab_project_share_path
  run        = true

  services = {
    gitlab = {
      image          = "gitlab/gitlab-ce:${var.gitlab_version}"
      container_name = "gitlab"
      hostname       = "gitlab"
      restart        = "unless-stopped"

      environment = {
        TZ                    = var.gitlab_timezone
        GITLAB_OMNIBUS_CONFIG = local.gitlab_omnibus_config
      }

      ports = concat([
        {
          target    = tonumber(var.gitlab_http_port)
          published = var.gitlab_http_port
        },
        {
          target    = 22
          published = var.gitlab_ssh_port
        },
        ], var.enable_gitlab_registry ? [
        {
          target    = tonumber(var.gitlab_registry_port)
          published = var.gitlab_registry_port
        },
      ] : [])

      volumes = [
        {
          type   = "bind"
          source = "/volume1/docker/gitlab/config"
          target = "/etc/gitlab"
        },
        {
          type   = "bind"
          source = "/volume1/docker/gitlab/logs"
          target = "/var/log/gitlab"
        },
        {
          type   = "bind"
          source = "/volume1/docker/gitlab/data"
          target = "/var/opt/gitlab"
        },
      ]
    }
  }
}

# -----------------------------------------------------------------------------
# GitLab Runner — Docker executor for CI/CD pipelines
# -----------------------------------------------------------------------------

resource "synology_container_project" "gitlab_runner" {
  for_each = var.enable_gitlab_runner ? { gitlab_runner = true } : {}

  name       = "gitlab-runner"
  share_path = var.gitlab_runner_share_path
  run        = true

  services = {
    "gitlab-runner" = {
      image          = "gitlab/gitlab-runner:${var.gitlab_runner_image}"
      container_name = "gitlab-runner"
      hostname       = "gitlab-runner"
      restart        = "unless-stopped"

      environment = {
        TZ = var.gitlab_timezone
      }

      volumes = [
        {
          type   = "bind"
          source = "/volume1/docker/gitlab-runner/config"
          target = "/etc/gitlab-runner"
        },
        {
          type   = "bind"
          source = "/var/run/docker.sock"
          target = "/var/run/docker.sock"
        },
      ]
    }
  }
}

# -----------------------------------------------------------------------------
# Docker Registry — S3-backed container registry using MinIO
# -----------------------------------------------------------------------------

resource "synology_container_project" "registry" {
  for_each = var.enable_registry ? { registry = true } : {}

  name       = "registry"
  share_path = var.registry_share_path
  run        = true

  services = {
    registry = {
      image          = "registry:${var.registry_version}"
      container_name = "registry"
      hostname       = "registry"
      restart        = "unless-stopped"

      environment = {
        REGISTRY_STORAGE                   = "s3"
        REGISTRY_STORAGE_S3_REGION         = "us-east-1"
        REGISTRY_STORAGE_S3_BUCKET         = var.minio_registry_bucket
        REGISTRY_STORAGE_S3_ENDPOINT       = var.minio_endpoint
        REGISTRY_STORAGE_S3_ACCESSKEY      = var.minio_root_user
        REGISTRY_STORAGE_S3_SECRETKEY      = var.minio_root_password
        REGISTRY_STORAGE_S3_V4AUTH         = "true"
        REGISTRY_STORAGE_S3_SECURE         = "false"
        REGISTRY_STORAGE_S3_ROOTDIRECTORY  = "/"
        REGISTRY_STORAGE_S3_FORCEPATHSTYLE = "true"
      }

      ports = [
        {
          target    = 5000
          published = var.registry_port
        },
      ]

      volumes = [
        {
          type   = "bind"
          source = "/volume1/docker/registry/data"
          target = "/var/lib/registry"
        },
      ]
    }
  }
}
