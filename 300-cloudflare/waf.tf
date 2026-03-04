# =============================================================================
# WAF CUSTOM FIREWALL RULES
# =============================================================================

# Web Application Firewall custom rules for jclee.me zone
# Uses cloudflare_ruleset for zone-scoped HTTP request filtering

resource "cloudflare_ruleset" "waf_custom" {
  count = can(regex("^[0-9a-f]{32}$", var.cloudflare_zone_id)) ? 1 : 0

  zone_id     = local.effective_cloudflare_zone_id
  kind        = "zone"
  phase       = "http_request_firewall_custom"
  name        = "Custom WAF Rules"
  description = "Custom WAF rules for jclee.me - bot blocking, path filtering, rate limiting, and country challenges"

  rules = [
    # Rule 1: Block known bad bots
    {
      description = "Block known bad bots - SemrushBot, AhrefsBot, MJ12bot, DotBot, PetalBot"
      expression  = "http.user_agent contains \"SemrushBot\" or http.user_agent contains \"AhrefsBot\" or http.user_agent contains \"MJ12bot\" or http.user_agent contains \"DotBot\" or http.user_agent contains \"PetalBot\""
      action      = "block"
      enabled     = true
    },
    # Rule 2: Block suspicious paths
    {
      description = "Block suspicious paths - .env, wp-admin, wp-login, xmlrpc, phpmyadmin, .git, config.json, actuator"
      expression  = "not http.request.uri.path within {\"/\" \"/grafana\" \"/kibana\" \"/elasticsearch\" \"/api\" \"/archon\" \"/mcphub\" \"/n8n\" \"/vault\" \"/supabase\"} and (http.request.uri.path contains \"/.env\" or http.request.uri.path contains \"/wp-admin\" or http.request.uri.path contains \"/wp-login.php\" or http.request.uri.path contains \"/xmlrpc.php\" or http.request.uri.path contains \"/phpmyadmin\" or http.request.uri.path contains \"/.git\" or http.request.uri.path contains \"/config.json\" or http.request.uri.path contains \"/actuator\")"
      action      = "block"
      enabled     = true
    },
    # Rule 3: Rate limit login/API auth paths
    {
      description = "Rate limit login and auth API paths with managed challenge"
      expression  = "http.request.uri.path contains \"/login\" or http.request.uri.path contains \"/api/auth\""
      action      = "managed_challenge"
      enabled     = true
    },
    # Rule 4: Block non-standard HTTP methods
    {
      description = "Block non-standard HTTP methods except OPTIONS for legitimate API paths"
      expression  = "not http.request.method within {\"GET\" \"POST\" \"HEAD\"} and not (http.request.method eq \"OPTIONS\" and http.request.uri.path within {\"/api\" \"/api/\"})"
      action      = "block"
      enabled     = true
    },
    # Rule 5: Country-based challenge for high-risk countries
    {
      description = "Challenge requests from non-allowed countries (KR, US, JP, DE, GB, CA, AU, NL, SE, FR only)"
      expression  = "not ip.geoip.country in {\"KR\" \"US\" \"JP\" \"DE\" \"GB\" \"CA\" \"AU\" \"NL\" \"SE\" \"FR\"}"
      action      = "managed_challenge"
      enabled     = true
    },
    # Rule 6: Block empty or missing user-agent
    {
      description = "Challenge requests with empty user-agent string"
      expression  = "http.user_agent eq \"\""
      action      = "managed_challenge"
      enabled     = true
    }
  ]
}
