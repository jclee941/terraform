# ============================================================================
# Ollama workspace test — provider declarations
# ============================================================================
# Required for terraform test framework to resolve provider blocks.
# This workspace has no providers — it only consumes remote state.
# ============================================================================

terraform {
  required_version = ">= 1.7, < 2.0"
}
