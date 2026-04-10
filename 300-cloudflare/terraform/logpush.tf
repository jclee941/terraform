# ============================================
# Cloudflare Logpush — Workers Trace Events → Logstash
# ============================================

resource "cloudflare_logpush_job" "worker_traces" {
  account_id = local.effective_cloudflare_account_id
  name       = "worker-traces-to-logstash"
  dataset    = "workers_trace_events"
  enabled    = true

  destination_conf = "https://logstash-ingest.${var.homelab_domain}/"

  output_options = {
    field_names      = ["EventTimestampMs", "Outcome", "Exceptions", "Logs", "ScriptName", "ScriptVersion", "Event"]
    timestamp_format = "rfc3339"
  }
}
