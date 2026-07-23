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
  # All traffic routes DIRECT to backends (no reverse proxy)
  # ============================================

  homelab_services = {
    elk      = { subdomain = "elk", origin = "http://${var.elk_ip}:5601" }
    kibana   = { subdomain = "kibana", origin = "http://${var.elk_ip}:5601" }
    es       = { subdomain = "es", origin = "http://${var.elk_ip}:9200" }
    nas      = { subdomain = "nas", origin = "https://${var.synology_nas_ip}:5001", no_tls_verify = true }
    registry = { subdomain = "registry", origin = "http://${var.synology_nas_ip}:5051" }
  }

  # HTTP services exposed directly via Cloudflare Tunnel (no reverse proxy)
  direct_services = {
    grafana   = { subdomain = "grafana", origin = "http://${var.synology_nas_ip}:3456" }
    minio     = { subdomain = "minio", origin = "http://${var.synology_nas_ip}:9001" }
    minio-api = { subdomain = "minio-api", origin = "http://${var.synology_nas_ip}:9000" }
    youtube   = { subdomain = "youtube", origin = "http://${var.youtube_ip}:30800" }
    idle      = { subdomain = "idle", origin = "http://${var.youtube_ip}:6080" }
  }

  # TCP/non-HTTP services exposed directly via Cloudflare Tunnel
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
    # Direct HTTP: code-server on jclee-dev VM
    code = {
      subdomain = "code"
      name      = "code-server"
      origin    = "http://${var.jclee_dev_ip}:8888"
    }
  }

}
