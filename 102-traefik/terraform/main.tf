locals {
  hosts = try(data.terraform_remote_state.infra.outputs.host_inventory, {})
}

# Config deployment (elk.yml, filebeat) is handled by
# 100-pve/main.tf via config-renderer templates (dynamic IPs from hosts.tf).
# Static config/ files with hardcoded IPs are kept as reference only.
#
# To add Traefik provider resources in the future:
#   required_providers { traefik = { source = "..." } }
#   provider "traefik" { endpoint = "http://${local.hosts.traefik.ip}:8080" }
