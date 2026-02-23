provider "grafana" {
  url  = var.grafana_url
  auth = local.effective_grafana_auth
}

provider "onepassword" {
  service_account_token = trimspace(var.op_service_account_token)
}
