variable "elasticsearch_url" {
  description = "Elasticsearch endpoint URL"
  type        = string
  default     = "http://192.168.50.105:9200"

  validation {
    condition     = can(regex("^https?://", var.elasticsearch_url))
    error_message = "elasticsearch_url must be a valid HTTP(S) URL."
  }
}

variable "elasticsearch_username" {
  description = "Elasticsearch username (empty if xpack security disabled)"
  type        = string
  default     = "elastic"
}

variable "elasticsearch_password" {
  description = "Elasticsearch password (empty if xpack security disabled)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "kibana_url" {
  description = "Kibana endpoint URL"
  type        = string
  default     = "http://192.168.50.105:5601"

  validation {
    condition     = can(regex("^https?://", var.kibana_url))
    error_message = "kibana_url must be a valid HTTP(S) URL."
  }
}

variable "op_service_account_token" {
  description = "1Password service account token"
  type        = string
  sensitive   = true
  default     = ""
}

variable "onepassword_vault_name" {
  description = "1Password vault name for secret lookups"
  type        = string
  default     = "homelab"

  validation {
    condition     = length(var.onepassword_vault_name) > 0
    error_message = "onepassword_vault_name must not be empty."
  }
}
