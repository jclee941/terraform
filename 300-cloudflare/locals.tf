locals {
  inventory = yamldecode(file("${path.module}/inventory/secrets.yaml"))

  all_secrets = try(local.inventory.secrets, [])

  cf_store_secrets = sort([
    for secret in local.all_secrets : secret.name
    if try(secret.targets.cf_store, false) == true
  ])

  total_secrets_count = length(local.all_secrets)

  # ============================================
  # homelab services exposed via Cloudflare Tunnel
  # All traffic routes through Traefik (192.168.50.102)
  # ============================================

  homelab_services = {
    elk          = { subdomain = "elk" }
    kibana       = { subdomain = "kibana" }
    es           = { subdomain = "es" }
    grafana      = { subdomain = "grafana" }
    mcphub       = { subdomain = "mcphub" }
    archon       = { subdomain = "archon" }
    supabase     = { subdomain = "supabase" }
    nas          = { subdomain = "nas" }
    n8n          = { subdomain = "n8n" }
    opencode     = { subdomain = "opencode" }
    opencode-api = { subdomain = "opencode-api" }
    gitlab       = { subdomain = "gitlab" }
  }

  # TCP/non-HTTP services exposed directly via Cloudflare Tunnel (bypass Traefik)
  tcp_services = {
    synology-ssh = {
      subdomain = "synology-ssh"
      name      = "Synology SSH"
      origin    = "tcp://${var.synology_nas_ip}:22"
    }
    rdp = {
      subdomain = "rdp"
      name      = "RDP"
      origin    = "tcp://${var.jclee_ip}:3389"
    }
    oc-rdp = {
      subdomain = "oc-rdp"
      name      = "OpenCode RDP"
      origin    = "tcp://${var.jclee_dev_ip}:3389"
    }
    jclee-ssh = {
      subdomain = "jclee-ssh"
      name      = "JCLee SSH"
      origin    = "tcp://${var.jclee_ip}:22"
    }
    youtube-ssh = {
      subdomain = "youtube-ssh"
      name      = "YouTube SSH"
      origin    = "tcp://${var.youtube_ip}:22"
    }
    ssh = {
      subdomain = "ssh"
      name      = "SSH"
      origin    = "tcp://${var.jclee_dev_ip}:22"
    }
  }

  # Services requiring Cloudflare Access protection
  # All homelab HTTP services are protected by CF Access email auth
  restricted_services = {
    elk          = { subdomain = "elk", name = "ELK" }
    kibana       = { subdomain = "kibana", name = "Kibana" }
    es           = { subdomain = "es", name = "Elasticsearch" }
    grafana      = { subdomain = "grafana", name = "Grafana" }
    mcphub       = { subdomain = "mcphub", name = "MCP Hub" }
    archon       = { subdomain = "archon", name = "Archon" }
    supabase     = { subdomain = "supabase", name = "Supabase" }
    n8n          = { subdomain = "n8n", name = "n8n" }
    nas          = { subdomain = "nas", name = "NAS" }
    opencode     = { subdomain = "opencode", name = "OpenCode" }
    opencode-api = { subdomain = "opencode-api", name = "OpenCode API" }
    gitlab       = { subdomain = "gitlab", name = "GitLab" }
  }

  # Services that allow internal network bypass (no CF Access auth required from homelab IP)
  internal_bypass_services = ["elk", "kibana", "es", "grafana", "mcphub", "archon", "supabase", "n8n", "nas", "opencode", "opencode-api", "gitlab"]

}
