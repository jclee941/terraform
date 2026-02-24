provider "slack" {
  token = local.effective_slack_token
}

provider "onepassword" {
  service_account_token = trimspace(var.op_service_account_token)
}
