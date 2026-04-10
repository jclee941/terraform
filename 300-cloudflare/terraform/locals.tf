locals {
  inventory = yamldecode(file("${path.module}/../inventory/secrets.yaml"))

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
    mcphub       = { subdomain = "mcphub" }
    archon       = { subdomain = "archon" }
    supabase     = { subdomain = "supabase" }
    nas          = { subdomain = "nas" }
    n8n          = { subdomain = "n8n" }
    opencode-api = { subdomain = "opencode-api" }
    registry     = { subdomain = "registry" }
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

}
