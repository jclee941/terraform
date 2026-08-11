terraform {
  required_version = ">= 1.7, < 2.0"

  required_providers {
    synology = {
      source  = "synology-community/synology"
      version = "~> 0.6"
    }
    onepassword = {
      source  = "1Password/onepassword"
      version = "~> 3.2"
    }
  }
}

variable "synology_host" {
  description = "Synology DSM HTTPS URL"
  type        = string
  default     = "https://192.168.50.215:5001"

  validation {
    condition     = can(regex("^https://", var.synology_host))
    error_message = "synology_host must start with https://"
  }
}

output "service_url" {
  description = "Validated Synology service URL"
  value       = var.synology_host
}
