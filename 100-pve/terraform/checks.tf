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

check "startup_guest_memory_budget" {
  assert {
    condition     = local.startup_guest_minimum_memory_mb <= local.startup_guest_budget_mb
    error_message = "Boot-time guaranteed guest memory ${local.startup_guest_minimum_memory_mb}MB exceeds the ${local.startup_guest_budget_mb}MB budget reserved for VM 200 and always-on infrastructure."
  }
}

resource "terraform_data" "resource_budget_guard" {
  input = {
    startup_guest_memory_mb = local.startup_guest_minimum_memory_mb
    total_guest_cpu_limit   = local.total_guest_cpu_limit
    total_guest_disk_gb     = local.total_guest_disk_gb
  }

  lifecycle {
    precondition {
      condition     = local.startup_guest_minimum_memory_mb <= local.startup_guest_budget_mb
      error_message = "Guaranteed guest memory ${local.startup_guest_minimum_memory_mb}MB exceeds the blocking ${local.startup_guest_budget_mb}MB startup budget."
    }

    precondition {
      condition     = local.total_guest_cpu_limit <= local.proxmox_cpu_limit_budget
      error_message = "Aggregate guest CPU limit ${local.total_guest_cpu_limit} exceeds the ${local.proxmox_cpu_limit_budget}-core host budget."
    }

    precondition {
      condition     = local.total_guest_disk_gb <= local.proxmox_ssd_allocation_limit_gb
      error_message = "Guest disk allocation ${local.total_guest_disk_gb}GB exceeds the ${local.proxmox_ssd_allocation_limit_gb}GB thin-pool allocation budget."
    }
  }
}

check "proxmox_provider_token_required" {
  assert {
    condition     = length(local.effective_proxmox_api_token) > 0
    error_message = "Proxmox provider token is required. Set 1Password secret key 'proxmox_api_token_value' (preferred) or provide var.proxmox_api_token override."
  }
}

check "deploy_ssh_key_required" {
  assert {
    condition     = !(var.deploy_lxc_configs || var.deploy_vm_configs) || length(trimspace(lookup(module.onepassword_secrets.secrets, "proxmox_ssh_private_key", ""))) > 0
    error_message = "deploy_lxc_configs/deploy_vm_configs requires onepassword secret key 'proxmox_ssh_private_key' in item 'proxmox' section 'secrets'."
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
