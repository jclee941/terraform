# Tests for modules/shared/onepassword-secrets
# Validates module configuration and 1Password data source setup.
# Uses mock_provider to avoid requiring actual 1Password credentials.

mock_provider "onepassword" {}

variables {
  vault_name = "homelab"
}

run "default_vault_name" {
  command = plan

  assert {
    condition     = data.onepassword_vault.this.name == "homelab"
    error_message = "Default vault_name should be 'homelab'."
  }
}

run "custom_vault_name" {
  command = plan

  variables {
    vault_name = "Production"
  }

  assert {
    condition     = data.onepassword_vault.this.name == "Production"
    error_message = "Custom vault_name should be respected."
  }
}

run "all_item_titles" {
  command = plan

  assert {
    condition     = data.onepassword_item.this["cloudflare"].title == "cloudflare"
    error_message = "Cloudflare item title should be 'cloudflare'."
  }

  assert {
    condition     = data.onepassword_item.this["elk"].title == "elk"
    error_message = "ELK item title should be 'elk'."
  }

  assert {
    condition     = data.onepassword_item.this["github"].title == "github"
    error_message = "GitHub item title should be 'github'."
  }

  assert {
    condition     = data.onepassword_item.this["proxmox"].title == "proxmox"
    error_message = "Proxmox item title should be 'proxmox'."
  }

  assert {
    condition     = data.onepassword_item.this["telegram"].title == "telegram"
    error_message = "Telegram item title should be 'telegram'."
  }
}
