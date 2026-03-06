provider "google" {
  project     = local.effective_gcp_project
  region      = var.gcp_region
  credentials = local.effective_gcp_credentials
}

provider "onepassword" {}
