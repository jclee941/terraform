terraform {
  required_version = ">= 1.7, < 2.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
  }
}

# NOTE(ephemeral): These data sources CANNOT be converted to ephemeral resources
# with the current architecture. Secrets flow into templatefile() → local_file
# resources via config_renderer, and ephemeral values cannot feed into regular
# resource attributes. To enable ephemeral secrets:
#   1. Expand vault-agent template_mappings to render ALL secret-dependent configs
#      at runtime (instead of Terraform plan-time via config_renderer)
#   2. Remove secret values from template_vars merge in 100-pve/main.tf
#   3. Then convert these data sources to ephemeral vault_kv_secret_v2
# See: https://registry.terraform.io/providers/hashicorp/vault/latest/docs/ephemeral-resources/kv_secret_v2
data "vault_kv_secret_v2" "grafana" {
  mount = var.vault_mount
  name  = "homelab/grafana"
}

data "vault_kv_secret_v2" "glitchtip" {
  mount = var.vault_mount
  name  = "homelab/glitchtip"
}

data "vault_kv_secret_v2" "proxmox" {
  mount = var.vault_mount
  name  = "homelab/proxmox"
}

data "vault_kv_secret_v2" "github" {
  mount = var.vault_mount
  name  = "homelab/github"
}

data "vault_kv_secret_v2" "exa" {
  mount = var.vault_mount
  name  = "homelab/exa"
}

data "vault_kv_secret_v2" "splunk" {
  mount = var.vault_mount
  name  = "homelab/splunk"
}

data "vault_kv_secret_v2" "supabase" {
  mount = var.vault_mount
  name  = "homelab/supabase"
}

data "vault_kv_secret_v2" "archon" {
  mount = var.vault_mount
  name  = "homelab/archon"
}

data "vault_kv_secret_v2" "cloudflare" {
  mount = var.vault_mount
  name  = "homelab/cloudflare"
}

data "vault_kv_secret_v2" "n8n" {
  mount = var.vault_mount
  name  = "homelab/n8n"
}

data "vault_kv_secret_v2" "mcphub" {
  mount = var.vault_mount
  name  = "homelab/mcphub"
}

data "vault_kv_secret_v2" "elk" {
  mount = var.vault_mount
  name  = "homelab/elk"
}
