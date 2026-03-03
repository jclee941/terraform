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
# Default vault name is "homelab" — override via var.vault_name.
data "onepassword_vault" "this" {
  name = var.vault_name
}

# ---------------------------------------------------------------------------
# Data sources — one per service via for_each.
# Each 1Password item should contain a section named "secrets" with fields
# matching the original Vault KV key names.
#
# Item structure:
#   Item: "grafana"  (category: password)
#     └── Section: "secrets"
#         ├── Field: "admin_password"        (CONCEALED)
#         └── Field: "service_account_token" (CONCEALED)
# ---------------------------------------------------------------------------

locals {
  # Items that are always looked up.
  required_items = toset([
    "archon",
    "cloudflare",
    "elk",
    "exa",
    "github",
    "glitchtip",
    "grafana",
    "mcphub",
    "n8n",
    "proxmox",
    "slack",
    "supabase",
    "synology",
    "youtube",
  ])

  # Items conditionally looked up.
  optional_items = var.enable_pbs ? toset(["pbs"]) : toset([])

  # Combined set for the for_each.
  all_items = setunion(local.required_items, local.optional_items)
}

data "onepassword_item" "this" {
  for_each = local.all_items
  vault    = data.onepassword_vault.this.uuid
  title    = each.key
}
