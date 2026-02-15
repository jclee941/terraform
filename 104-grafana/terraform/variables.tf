variable "grafana_url" {
  description = "Grafana instance URL"
  type        = string
  default     = "http://192.168.50.104:3000"
}

variable "grafana_auth" {
  description = "Grafana API key or service account token"
  type        = string
  sensitive   = true
}

variable "n8n_webhook_url" {
  description = "n8n webhook URL for alert notifications"
  type        = string
  sensitive   = true
}

locals {
  infra_hosts = try(data.terraform_remote_state.infra.outputs.host_inventory, {})
  grafana_ip  = try(local.infra_hosts.grafana.ip, "192.168.50.104")
  elk_ip      = try(local.infra_hosts.elk.ip, "192.168.50.105")
  mcphub_ip   = try(local.infra_hosts.mcphub.ip, "192.168.50.112")
}
