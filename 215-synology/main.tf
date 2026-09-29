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
# MailPlus - primary domain catch-all routing
# -----------------------------------------------------------------------------

resource "synology_api" "mailplus_catch_all" {
  for_each = var.enable_mailplus_catch_all ? { primary = true } : {}

  api     = "SYNO.MailPlusServer.Domain.Settings"
  method  = "set"
  version = 1

  parameters = {
    domain_id = tostring(var.mailplus_domain_id)
    catch_all = jsonencode({
      enable  = true
      setting = var.mailplus_catch_all_user
    })
  }
}
