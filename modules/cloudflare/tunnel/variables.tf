variable "name" {
  description = "Cloudflare tunnel name."
  type        = string
}

variable "account_id" {
  description = "Cloudflare account ID that owns the tunnel."
  type        = string
}

variable "ingress" {
  description = "Optional cloudflared ingress rules for the tunnel config."
  type = list(object({
    hostname = optional(string)
    service  = string
  }))
  default = null
}
