# -----------------------------------------------------------------------------
# 1Password
# -----------------------------------------------------------------------------

variable "onepassword_vault_name" {
  description = "1Password vault name for secret retrieval"
  type        = string
  default     = "homelab"

  validation {
    condition     = length(var.onepassword_vault_name) > 0
    error_message = "vault name must not be empty"
  }
}

# -----------------------------------------------------------------------------
# Synology DSM
# -----------------------------------------------------------------------------

variable "synology_host" {
  description = "Synology DSM HTTPS URL (e.g. https://192.168.50.215:5001)"
  type        = string
  default     = "https://192.168.50.215:5001"

  validation {
    condition     = can(regex("^https://", var.synology_host))
    error_message = "synology_host must start with https://"
  }
}

variable "synology_user" {
  description = "Synology DSM admin username (overridden by 1Password if available)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "synology_password" {
  description = "Synology DSM admin password (overridden by 1Password if available)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "synology_skip_cert_check" {
  description = "Skip TLS certificate verification for self-signed DSM certs"
  type        = bool
  default     = true
}

variable "enable_container_manager_package" {
  description = "Manage ContainerManager package installation via Terraform"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Synology MailPlus
# -----------------------------------------------------------------------------

variable "enable_mailplus_catch_all" {
  description = "Route otherwise-unmatched addresses in the primary MailPlus domain to one DSM user"
  type        = bool
  default     = true
}

variable "mailplus_domain_id" {
  description = "MailPlus primary domain identifier returned by SYNO.MailPlusServer.Domain/list"
  type        = number
  default     = 1

  validation {
    condition     = var.mailplus_domain_id > 0 && floor(var.mailplus_domain_id) == var.mailplus_domain_id
    error_message = "mailplus_domain_id must be a positive integer"
  }
}

variable "mailplus_catch_all_user" {
  description = "DSM user that receives otherwise-unmatched mail for the primary MailPlus domain"
  type        = string
  default     = "jclee"

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+$", var.mailplus_catch_all_user))
    error_message = "mailplus_catch_all_user must be a valid DSM account name"
  }
}

# -----------------------------------------------------------------------------
# Portainer
# -----------------------------------------------------------------------------

variable "enable_portainer" {
  description = "Enable Portainer CE container deployment on Synology"
  type        = bool
  default     = false
}



variable "portainer_https_port" {
  description = "Published HTTPS port for Portainer web UI"
  type        = string
  default     = "9443"
}

variable "portainer_edge_port" {
  description = "Published TCP port for Portainer Edge agent communication"
  type        = string
  default     = "8000"
}
