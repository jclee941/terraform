terraform {
  required_version = ">= 1.7, < 2.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
  }
}

# TODO(vault-v5): Convert data sources below to ephemeral resources (vault provider v5.x + TF >= 1.11)
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
