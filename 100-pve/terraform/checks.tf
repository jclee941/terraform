# =============================================================================
# VALIDATION CHECKS (Terraform 1.5+)
# =============================================================================

check "vmid_range" {
  assert {
    condition = alltrue([
      for k, v in local.vmid_validation : v.in_range
    ])
    error_message = join("\n", [
      for k, v in local.vmid_validation : v.message if !v.in_range
    ])
  }
}

check "ip_subnet" {
  assert {
    condition = alltrue([
      for k, v in local.ip_validation : v.in_subnet
    ])
    error_message = join("\n", [
      for k, v in local.ip_validation : v.message if !v.in_subnet
    ])
  }
}

check "memory_requirements" {
  assert {
    condition = alltrue([
      for k, v in local.memory_validation : v.sufficient && v.divisible && v.swap_valid
    ])
    error_message = join("\n", [
      for k, v in local.memory_validation : v.message if !(v.sufficient && v.divisible && v.swap_valid)
    ])
  }
}

check "proxmox_provider_token_required" {
  assert {
    condition     = length(local.effective_proxmox_api_token) > 0
    error_message = "Proxmox provider token is required. Set 1Password secret key 'proxmox_api_token_value' (preferred) or provide var.proxmox_api_token override."
  }
}

check "mcphub_required_secrets" {
  assert {
    condition = alltrue([
      for k in [
        "mcphub_admin_password",
        "mcphub_op_connect_token",
        "mcphub_op_service_account_token",
        "mcphub_proxmox_token_name",
        "mcphub_proxmox_token_value",
      ] : length(trimspace(lookup(module.onepassword_secrets.secrets, k, ""))) > 0
    ])
    error_message = "MCPHub required 1Password fields are missing. Required keys: mcphub_admin_password, mcphub_op_connect_token, mcphub_op_service_account_token, mcphub_proxmox_token_name, mcphub_proxmox_token_value"
  }
}

check "deploy_ssh_key_required" {
  assert {
    condition     = !(var.deploy_lxc_configs || var.deploy_vm_configs) || length(trimspace(lookup(module.onepassword_secrets.secrets, "proxmox_ssh_private_key", ""))) > 0
    error_message = "deploy_lxc_configs/deploy_vm_configs requires onepassword secret key 'proxmox_ssh_private_key' in item 'proxmox' section 'secrets'."
  }
}

# Blocking guard (not a `check` block — those only warn). A terraform_data with a
# lifecycle precondition FAILS `terraform plan` when enable_registry is true but the
# registry MinIO credentials are missing or still the insecure 'minioadmin' default,
# preventing minioadmin from silently reaching VM cloud-init.
resource "terraform_data" "registry_minio_secrets_guard" {
  count = var.enable_registry ? 1 : 0

  lifecycle {
    precondition {
      condition = (
        length(trimspace(lookup(module.onepassword_secrets.secrets, "registry_minio_user", ""))) > 0 &&
        length(trimspace(lookup(module.onepassword_secrets.secrets, "registry_minio_password", ""))) > 0 &&
        trimspace(lookup(module.onepassword_secrets.secrets, "registry_minio_user", "")) != "minioadmin" &&
        trimspace(lookup(module.onepassword_secrets.secrets, "registry_minio_password", "")) != "minioadmin"
      )
      error_message = "enable_registry is true but registry MinIO credentials are missing or still the insecure 'minioadmin' default. Add a 'registry' item (minio user + password) to the 1Password vault, or set enable_registry = false."
    }
  }
}

check "no_placeholder_secrets" {
  assert {
    condition     = length(local.placeholder_template_secret_keys) == 0
    error_message = "1Password secrets contain placeholder values that must be replaced with real credentials: ${join(", ", local.placeholder_template_secret_keys)}"
  }
}

check "no_placeholder_metadata" {
  assert {
    condition     = length(local.placeholder_template_metadata_keys) == 0
    error_message = "1Password metadata contain placeholder values consumed by templates: ${join(", ", local.placeholder_template_metadata_keys)}"
  }
}
