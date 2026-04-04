terraform {
  required_version = ">= 1.7, < 2.0"
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
