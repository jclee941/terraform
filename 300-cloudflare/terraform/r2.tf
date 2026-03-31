# ============================================
# R2 Bucket for Synology Cache
# ============================================

resource "cloudflare_r2_bucket" "synology_cache" {
  account_id = local.effective_cloudflare_account_id
  name       = "synology-cache"
  location   = "APAC"
}
