bucket = "jclee-tf-state"
region = "auto"

endpoints = {
  s3 = "https://a8d9c67f586acdd15eebcc65ca3aa5bb.r2.cloudflarestorage.com"
}

# State locking via lock file on R2 (Terraform >= 1.10)
# Prevents concurrent state modifications in local dev.
# CI-level locking handled by GitHub Actions concurrency groups.
use_lockfile = true

skip_credentials_validation = true
skip_metadata_api_check     = true
skip_region_validation      = true
skip_requesting_account_id  = true
skip_s3_checksum            = true
use_path_style              = true
