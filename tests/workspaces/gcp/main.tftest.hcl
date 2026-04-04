# ============================================================================
# GCP workspace placeholder tests
# ============================================================================

run "gcp_workspace_id_is_set" {
  command = plan

  variables {
    workspace = "400-gcp"
  }

  assert {
    condition     = output.workspace_id == "400-gcp"
    error_message = "workspace_id output must match the GCP workspace identifier"
  }
}
