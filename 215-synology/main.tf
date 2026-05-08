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



# -----------------------------------------------------------------------------
# MinIO — S3-compatible object storage backend for Docker Registry
# -----------------------------------------------------------------------------

resource "synology_container_project" "minio" {
  for_each = var.enable_registry ? { minio = true } : {}

  name       = "minio"
  share_path = var.minio_share_path
  run        = true

  services = {
    minio = {
      image          = "minio/minio:${var.minio_version}"
      container_name = "minio"
      hostname       = "minio"
      restart        = "unless-stopped"
      command        = ["server", "/data", "--console-address", ":9001"]

      environment = {
        MINIO_ROOT_USER     = local.effective_minio_user
        MINIO_ROOT_PASSWORD = local.effective_minio_password
        MINIO_REGION_NAME   = "us-east-1"
      }

      ports = [
        {
          target    = 9000
          published = "9000"
        },
        {
          target    = 9001
          published = "9001"
        },
      ]

      volumes = [
        {
          type   = "bind"
          source = "/volume1/docker/minio/data"
          target = "/data"
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

  depends_on = [synology_container_project.minio]

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
        REGISTRY_STORAGE_S3_REGIONENDPOINT = var.minio_endpoint
        REGISTRY_STORAGE_S3_ACCESSKEY      = local.effective_minio_user
        REGISTRY_STORAGE_S3_SECRETKEY      = local.effective_minio_password
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
