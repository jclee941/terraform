# ============================================
# Workers Route for Synology API Proxy
# ============================================

resource "cloudflare_workers_route" "synology_proxy" {
  count   = var.enable_worker_route ? 1 : 0
  zone_id = local.effective_cloudflare_zone_id
  pattern = "${var.synology_domain}/api/*"
  script  = "synology-proxy"
}
