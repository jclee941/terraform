# ──────────────────────────────────────────────────────────────────────────────
# WAF — zone-level managed rulesets for application-layer security
# ──────────────────────────────────────────────────────────────────────────────

resource "cloudflare_ruleset" "zone_waf" {
  zone_id     = local.effective_cloudflare_zone_id
  name        = "Zone WAF Managed Rules"
  description = "Deploy Cloudflare Managed Ruleset and OWASP Core Ruleset"
  kind        = "zone"
  phase       = "http_request_firewall_managed"

  rules = [
    {
      action = "execute"
      action_parameters = {
        id = "efb7b8c949ac4650a09736fc376e9aee" # pragma: allowlist secret
      }
      expression  = "true"
      description = "Execute Cloudflare Managed Ruleset"
      enabled     = true
    },
    {
      action = "execute"
      action_parameters = {
        id = "4814384a9e5d4991b9815dcfc25d2f1f" # pragma: allowlist secret
      }
      expression  = "true"
      description = "Execute Cloudflare OWASP Core Ruleset"
      enabled     = true
    },
  ]
}
