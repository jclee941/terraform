# ============================================================================
# Slack workspace test — provider declarations
# ============================================================================
# Required for terraform test framework to resolve mock_provider blocks.
# Provider versions must match 320-slack/versions.tf.
# ============================================================================

terraform {
  required_version = ">= 1.7, < 2.0"

  required_providers {
    slack = {
      source  = "pablovarela/slack"
      version = "~> 1.0"
    }
    onepassword = {
      source  = "1Password/onepassword"
      version = "~> 3.2"
    }
  }
}
