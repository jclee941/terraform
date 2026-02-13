# ============================================
# Workers Route for Synology API Proxy
# ============================================

resource "cloudflare_workers_route" "synology_proxy" {
  count   = var.enable_worker_route ? 1 : 0
  zone_id = var.cloudflare_zone_id
  pattern = "${var.synology_domain}/api/*"
  script  = "synology-proxy"
}
