# ============================================
# Cloudflare Logpush — Workers Trace Events → Logstash
# ============================================

resource "cloudflare_logpush_job" "worker_traces" {
  account_id = local.effective_cloudflare_account_id
  name       = "worker-traces-to-logstash"
  dataset    = "workers_trace_events"
  enabled    = true

  destination_conf = join("", [
    "https://logstash-ingest.${var.homelab_domain}/",
    "?header_CF-Access-Client-Id=${cloudflare_zero_trust_access_service_token.logpush.client_id}",
    "&header_CF-Access-Client-Secret=${cloudflare_zero_trust_access_service_token.logpush.client_secret}",
  ])

  output_options = {
    field_names      = ["EventTimestampMs", "Outcome", "Exceptions", "Logs", "ScriptName", "ScriptVersion", "Event"]
    timestamp_format = "rfc3339"
  }
}
