# ============================================================================
# SafetyWallet workspace placeholder tests (template-only workspace)
# ============================================================================

run "safetywallet_workspace_id_is_set" {
  command = plan

  variables {
    workspace = "310-safetywallet"
  }

  assert {
    condition     = output.workspace_id == "310-safetywallet"
    error_message = "workspace_id output must match the SafetyWallet workspace identifier"
  }
}
