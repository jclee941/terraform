provider "grafana" {
  url  = var.grafana_url
  auth = local.effective_grafana_auth
}

provider "onepassword" {}
