variable "deploy_lxc_configs" {
  description = "Deploy LXC configs via SSH"
  type        = bool
  default     = false
}

variable "supabase_url" {
  description = "Supabase project URL (from Vault)"
  type        = string
  sensitive   = true
}

variable "supabase_anon_key" {
  description = "Supabase anonymous key (from Vault)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "openai_api_key" {
  description = "OpenAI API key (from Vault)"
  type        = string
  sensitive   = true
  default     = ""
}
