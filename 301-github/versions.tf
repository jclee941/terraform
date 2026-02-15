terraform {
  required_version = ">= 1.7, < 2.0"

  backend "s3" {
    key = "301-github/terraform.tfstate"
  }

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.6"
    }
  }
}

# ---------------------------------------------------------------------------
# Remote State: consume 100-pve infrastructure outputs
# Provides host_inventory (IPs, ports, VMIDs) and service_urls (derived URLs).
# ---------------------------------------------------------------------------
data "terraform_remote_state" "infra" {
  backend = "s3"

  config = {
    bucket                      = "jclee-tf-state"
    key                         = "100-pve/terraform.tfstate"
    region                      = "auto"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    use_path_style              = true
    endpoints = {
      s3 = "https://a8d9c67f586acdd15eebcc65ca3aa5bb.r2.cloudflarestorage.com"
    }
  }
}
