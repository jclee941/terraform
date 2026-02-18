terraform {
  required_version = ">= 1.7, < 2.0"

  required_providers {
    onepassword = {
      source  = "1Password/onepassword"
      version = "~> 3.2"
    }
  }
}

# Look up the 1Password vault by name.
# Default vault name is "Homelab" — override via var.vault_name.
data "onepassword_vault" "this" {
  name = var.vault_name
}

# ---------------------------------------------------------------------------
# Data sources — one per service, mirroring Vault KV v2 paths.
# Each 1Password item should contain a section named "secrets" with fields
# matching the original Vault KV key names.
#
# Item structure:
#   Item: "grafana"  (category: password)
#     └── Section: "secrets"
#         ├── Field: "admin_password"        (CONCEALED)
#         └── Field: "service_account_token" (CONCEALED)
# ---------------------------------------------------------------------------

data "onepassword_item" "grafana" {
  vault = data.onepassword_vault.this.uuid
  title = "grafana"
}

data "onepassword_item" "glitchtip" {
  vault = data.onepassword_vault.this.uuid
  title = "glitchtip"
}

data "onepassword_item" "proxmox" {
  vault = data.onepassword_vault.this.uuid
  title = "proxmox"
}

data "onepassword_item" "github" {
  vault = data.onepassword_vault.this.uuid
  title = "github"
}

data "onepassword_item" "exa" {
  vault = data.onepassword_vault.this.uuid
  title = "exa"
}

data "onepassword_item" "splunk" {
  vault = data.onepassword_vault.this.uuid
  title = "splunk"
}

data "onepassword_item" "supabase" {
  vault = data.onepassword_vault.this.uuid
  title = "supabase"
}

data "onepassword_item" "archon" {
  vault = data.onepassword_vault.this.uuid
  title = "archon"
}

data "onepassword_item" "cloudflare" {
  vault = data.onepassword_vault.this.uuid
  title = "cloudflare"
}

data "onepassword_item" "n8n" {
  vault = data.onepassword_vault.this.uuid
  title = "n8n"
}

data "onepassword_item" "mcphub" {
  vault = data.onepassword_vault.this.uuid
  title = "mcphub"
}

data "onepassword_item" "elk" {
  vault = data.onepassword_vault.this.uuid
  title = "elk"
}
