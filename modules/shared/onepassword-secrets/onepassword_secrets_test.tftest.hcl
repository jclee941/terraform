# Tests for modules/shared/onepassword-secrets
# Validates module configuration and 1Password data source setup.
# Uses mock_provider to avoid requiring actual 1Password credentials.

mock_provider "onepassword" {}

variables {
  vault_name = "Homelab"
}

run "default_vault_name" {
  command = plan

  assert {
    condition     = data.onepassword_vault.this.name == "Homelab"
    error_message = "Default vault_name should be 'Homelab'."
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
    condition     = data.onepassword_item.grafana.title == "grafana"
    error_message = "Grafana item title should be 'grafana'."
  }

  assert {
    condition     = data.onepassword_item.elk.title == "elk"
    error_message = "ELK item title should be 'elk'."
  }

  assert {
    condition     = data.onepassword_item.cloudflare.title == "cloudflare"
    error_message = "Cloudflare item title should be 'cloudflare'."
  }

  assert {
    condition     = data.onepassword_item.mcphub.title == "mcphub"
    error_message = "MCPHub item title should be 'mcphub'."
  }

  assert {
    condition     = data.onepassword_item.n8n.title == "n8n"
    error_message = "n8n item title should be 'n8n'."
  }

  assert {
    condition     = data.onepassword_item.supabase.title == "supabase"
    error_message = "Supabase item title should be 'supabase'."
  }

  assert {
    condition     = data.onepassword_item.glitchtip.title == "glitchtip"
    error_message = "GlitchTip item title should be 'glitchtip'."
  }

  assert {
    condition     = data.onepassword_item.proxmox.title == "proxmox"
    error_message = "Proxmox item title should be 'proxmox'."
  }

  assert {
    condition     = data.onepassword_item.github.title == "github"
    error_message = "GitHub item title should be 'github'."
  }

  assert {
    condition     = data.onepassword_item.exa.title == "exa"
    error_message = "Exa item title should be 'exa'."
  }

  assert {
    condition     = data.onepassword_item.splunk.title == "splunk"
    error_message = "Splunk item title should be 'splunk'."
  }

  assert {
    condition     = data.onepassword_item.archon.title == "archon"
    error_message = "Archon item title should be 'archon'."
  }
}
