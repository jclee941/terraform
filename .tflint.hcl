# TFLint configuration for terraform monorepo
# Docs: https://github.com/terraform-linters/tflint/blob/master/docs/user-guide/config.md

config {
  # Module inspection (requires terraform init)
  call_module_type = "local"
}

plugin "terraform" {
  enabled = true
  version = "0.10.0"
  source  = "github.com/terraform-linters/tflint-ruleset-terraform"

  preset = "recommended"
}

# Enforce naming conventions
rule "terraform_naming_convention" {
  enabled = true

  variable {
    format = "snake_case"
  }

  locals {
    format = "snake_case"
  }

  output {
    format = "snake_case"
  }

  resource {
    format = "snake_case"
  }

  module {
    format = "snake_case"
  }

  data {
    format = "snake_case"
  }
}

# Require descriptions on variables and outputs
rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

# Prevent deprecated syntax
rule "terraform_deprecated_interpolation" {
  enabled = true
}

# Enforce consistent type declarations
rule "terraform_typed_variables" {
  enabled = true
}

# Warn on unused declarations
rule "terraform_unused_declarations" {
  enabled = true
}

# Standard module structure
# Disabled: this monorepo intentionally splits outputs by consumer
# (outputs-homelab.tf, outputs-jclee.tf, outputs-synology.tf) and co-locates
# some outputs with their resource file (e.g. backup_jobs.tf), which this rule
# forbids. The split-outputs convention is documented in the workspace AGENTS.md
# files, so the rule is turned off to match the intended structure.
rule "terraform_standard_module_structure" {
  enabled = false
}

# Require version constraints for providers in required_providers
rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}
