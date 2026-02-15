# Authentication
variable "cloudflare_api_token" {
  description = "Cloudflare API Token for authentication"
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for DNS and Access resources"
  type        = string
}

# Tunnel Configuration
variable "tunnels" {
  description = "Map of Zero Trust tunnels to create"
  type = map(object({
    name          = string
    tunnel_secret = optional(string)               # Base64-encoded, min 32 bytes
    config_src    = optional(string, "cloudflare") # "cloudflare" or "local"
    config = optional(object({
      ingress = list(object({
        hostname = optional(string)
        service  = string
        path     = optional(string)
      }))
    }))
  }))
  default = {}
}

# Access Applications
variable "access_applications" {
  description = "Map of Zero Trust Access applications"
  type = map(object({
    name                      = string
    domain                    = string
    type                      = optional(string, "self_hosted")
    session_duration          = optional(string, "24h")
    auto_redirect_to_identity = optional(bool, false)
    allowed_idps              = optional(list(string))
  }))
  default = {}
}

# Access Policies
variable "access_policies" {
  description = "Map of Access policies for applications"
  type = map(object({
    application_id = string
    name           = string
    decision       = string # "allow", "deny", "bypass", "non_identity"
    precedence     = number
    include = list(object({
      email        = optional(list(string))
      email_domain = optional(list(string))
      group        = optional(list(string))
      ip           = optional(list(string))
    }))
    exclude = optional(list(object({
      email        = optional(list(string))
      email_domain = optional(list(string))
      group        = optional(list(string))
      ip           = optional(list(string))
    })))
  }))
  default = {}
}

# R2 Buckets
variable "r2_buckets" {
  description = "Map of R2 buckets to create"
  type = map(object({
    name     = string
    location = string # "WNAM", "ENAM", "WEUR", "EEUR", "APAC"
  }))
  default = {}
}

# Workers
variable "workers" {
  description = "Map of Workers scripts to deploy"
  type = map(object({
    script_name  = string
    content_file = string
    bindings = optional(list(object({
      type         = string # "r2_bucket", "secret_text", "plain_text", "kv_namespace", "d1"
      name         = string
      bucket_name  = optional(string) # For R2 buckets
      text         = optional(string) # For secrets/plain text
      namespace_id = optional(string) # For KV
      database_id  = optional(string) # For D1
    })), [])
  }))
  default = {}
}

# Workers Routes
variable "worker_routes" {
  description = "Map of Workers routes"
  type = map(object({
    pattern     = string
    script_name = string
  }))
  default = {}
}

# DNS Records
variable "dns_records" {
  description = "Map of DNS records (typically CNAMEs for tunnels)"
  type = map(object({
    name    = string
    type    = string
    content = string
    proxied = optional(bool, true)
    ttl     = optional(number, 1)
  }))
  default = {}
}
