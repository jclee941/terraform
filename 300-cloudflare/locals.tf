locals {
  inventory = yamldecode(file("${path.module}/inventory/secrets.yaml"))

  all_secrets = try(local.inventory.secrets, [])

  github_repo_map   = try(local.inventory.github.repos, {})
  github_repo_names = sort(values(local.github_repo_map))

  github_secret_entries = flatten([
    for secret in local.all_secrets : [
      for repo_alias in try(secret.targets.github, []) : {
        key         = "${repo_alias}:${secret.name}"
        repository  = lookup(local.github_repo_map, repo_alias, repo_alias)
        secret_name = secret.name
      }
    ]
  ])

  github_secrets = {
    for entry in local.github_secret_entries : entry.key => entry
  }

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
    elk      = { subdomain = "elk", name = "ELK" }
    kibana   = { subdomain = "kibana", name = "Kibana" }
    es       = { subdomain = "es", name = "Elasticsearch" }
    grafana  = { subdomain = "grafana", name = "Grafana" }
    mcphub   = { subdomain = "mcphub", name = "MCP Hub" }
    archon   = { subdomain = "archon", name = "Archon" }
    supabase = { subdomain = "supabase", name = "Supabase" }
  }

  # Services that allow internal network bypass (no CF Access auth required from homelab IP)
  internal_bypass_services = ["elk", "kibana", "es", "grafana", "mcphub", "archon", "supabase", "n8n"]

}
