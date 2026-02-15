terraform {
  required_version = ">= 1.7, < 2.0"

  backend "s3" {
    key = "105-elk/terraform.tfstate"
  }

  required_providers {
    elasticstack = {
      source  = "elastic/elasticstack"
      version = "~> 0.11"
    }
  }
}

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
      s3 = "https://<ACCOUNT_ID>.r2.cloudflarestorage.com"
    }
  }
}
