terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
  }
}

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
