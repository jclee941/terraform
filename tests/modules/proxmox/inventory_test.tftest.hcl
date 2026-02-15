# =============================================================================
# Inventory Module Tests (DEPRECATED)
# =============================================================================
# Module: modules/proxmox/inventory
# Status: DEPRECATED — replaced by 100-pve/envs/prod/hosts.tf SSoT
# Purpose: Validate legacy host data and service derivations still function
#          until all consumers are migrated.
# =============================================================================

# -----------------------------------------------------------------------------
# Test: Hosts output contains expected entries
# Inventory has hardcoded locals for 9 hosts (missing supabase, archon, synology)
# -----------------------------------------------------------------------------
run "test_hosts_output_structure" {
  command = plan

  module {
    source = "../../../modules/proxmox/inventory"
  }

  # Verify key hosts exist
  assert {
    condition     = output.hosts["pve"] != null
    error_message = "hosts output must contain 'pve' entry"
  }

  assert {
    condition     = output.hosts["runner"] != null
    error_message = "hosts output must contain 'runner' entry"
  }

  assert {
    condition     = output.hosts["traefik"] != null
    error_message = "hosts output must contain 'traefik' entry"
  }

  assert {
    condition     = output.hosts["elk"] != null
    error_message = "hosts output must contain 'elk' entry"
  }

  assert {
    condition     = output.hosts["grafana"] != null
    error_message = "hosts output must contain 'grafana' entry"
  }
}

# -----------------------------------------------------------------------------
# Test: VMID-to-IP mapping follows convention (192.168.50.{VMID})
# -----------------------------------------------------------------------------
run "test_vmid_ip_convention" {
  command = plan

  module {
    source = "../../../modules/proxmox/inventory"
  }

  assert {
    condition     = output.hosts["pve"].ip == "192.168.50.100"
    error_message = "pve IP must be 192.168.50.100 (VMID 100)"
  }

  assert {
    condition     = output.hosts["runner"].ip == "192.168.50.101"
    error_message = "runner IP must be 192.168.50.101 (VMID 101)"
  }

  assert {
    condition     = output.hosts["elk"].ip == "192.168.50.105"
    error_message = "elk IP must be 192.168.50.105 (VMID 105)"
  }
}

# -----------------------------------------------------------------------------
# Test: Services output derives correct URLs
# -----------------------------------------------------------------------------
run "test_services_url_derivation" {
  command = plan

  module {
    source = "../../../modules/proxmox/inventory"
  }

  assert {
    condition     = output.services != null
    error_message = "services output must not be null"
  }
}

# -----------------------------------------------------------------------------
# Test: Prometheus targets exclude hypervisor
# Only non-hypervisor hosts should appear as scrape targets
# -----------------------------------------------------------------------------
run "test_prometheus_targets_exclude_hypervisor" {
  command = plan

  module {
    source = "../../../modules/proxmox/inventory"
  }

  assert {
    condition     = output.prometheus_targets != null
    error_message = "prometheus_targets output must not be null"
  }

  # pve (hypervisor) should NOT be in targets
  assert {
    condition     = !contains([for t in output.prometheus_targets : t], "192.168.50.100:9100")
    error_message = "prometheus_targets must NOT include hypervisor (pve) at 192.168.50.100:9100"
  }
}

# -----------------------------------------------------------------------------
# Test: Traefik backends include only hosts with ports
# -----------------------------------------------------------------------------
run "test_traefik_backends" {
  command = plan

  module {
    source = "../../../modules/proxmox/inventory"
  }

  assert {
    condition     = output.traefik_backends != null
    error_message = "traefik_backends output must not be null"
  }
}

# -----------------------------------------------------------------------------
# DEPRECATION NOTICE
# This module is a legacy duplicate of 100-pve/envs/prod/hosts.tf.
# Known gaps:
#   - Missing hosts: supabase(107), archon(108), synology(215)
#   - Hardcoded values (not dynamic)
#   - Duplicates env-config logic
# TODO: Migrate all consumers to env-config module, then remove.
# -----------------------------------------------------------------------------
