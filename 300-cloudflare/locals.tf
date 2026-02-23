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
    elk       = { subdomain = "elk" }
    kibana    = { subdomain = "kibana" }
    es        = { subdomain = "es" }
    glitchtip = { subdomain = "glitchtip" }
    grafana   = { subdomain = "grafana" }
    mcphub    = { subdomain = "mcphub" }
    vault     = { subdomain = "vault" }
    archon    = { subdomain = "archon" }
    supabase  = { subdomain = "supabase" }
    nas       = { subdomain = "nas" }
    n8n       = { subdomain = "n8n" }
    opencode  = { subdomain = "opencode" }
  }

  # Services requiring Cloudflare Access protection
  # All homelab HTTP services are protected by CF Access email auth
  restricted_services = {
    elk       = { subdomain = "elk", name = "ELK" }
    kibana    = { subdomain = "kibana", name = "Kibana" }
    es        = { subdomain = "es", name = "Elasticsearch" }
    glitchtip = { subdomain = "glitchtip", name = "GlitchTip" }
    grafana   = { subdomain = "grafana", name = "Grafana" }
    mcphub    = { subdomain = "mcphub", name = "MCP Hub" }
    vault     = { subdomain = "vault", name = "Vault" }
    archon    = { subdomain = "archon", name = "Archon" }
    supabase  = { subdomain = "supabase", name = "Supabase" }
    nas       = { subdomain = "nas", name = "NAS" }
    n8n       = { subdomain = "n8n", name = "n8n" }
    opencode  = { subdomain = "opencode", name = "OpenCode" }
  }

  # Non-HTTP services exposed via Cloudflare Tunnel (direct TCP, not via Traefik)
  tunnel_direct_services = {
    jclee-rdp = {
      subdomain = "rdp"
      service   = "rdp://192.168.50.200:3389"
    }
    oc-ssh = {
      subdomain = "ssh"
      service   = "ssh://192.168.50.200:22"
    }
  }
}
