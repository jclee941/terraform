terraform {
  required_version = ">= 1.7, < 2.0"
}

variable "workspace" {
  description = "Workspace identifier under test"
  type        = string

  validation {
    condition     = length(trimspace(var.workspace)) > 0
    error_message = "workspace must not be empty"
  }
}

output "workspace_id" {
  description = "Validated workspace identifier"
  value       = var.workspace
}
