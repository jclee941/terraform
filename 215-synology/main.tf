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
  name = "ContainerManager"
}

# -----------------------------------------------------------------------------
# Container Projects — Docker Compose stacks managed via Terraform
# -----------------------------------------------------------------------------
# Add synology_container_project resources here as services are onboarded.
# Example:
#
# resource "synology_container_project" "example" {
#   name       = "example"
#   share_path = "/docker/example"
#   run        = true
#
#   services = {
#     "app" = {
#       image   = "nginx:latest"
#       ports   = [{ target = 80, published = "8080" }]
#       restart = "unless-stopped"
#     }
#   }
# }
