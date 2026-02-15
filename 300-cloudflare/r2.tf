# ============================================
# R2 Bucket for Synology Cache
# ============================================

resource "cloudflare_r2_bucket" "synology_cache" {
  account_id = var.cloudflare_account_id
  name       = "synology-cache"
  location   = "APAC"
}

# ============================================
# R2 Bucket for Terraform State
# ============================================

resource "cloudflare_r2_bucket" "tf_state" {
  account_id = var.cloudflare_account_id
  name       = "jclee-tf-state"
  location   = "APAC"
}
