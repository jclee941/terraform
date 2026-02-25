provider "slack" {
  token = local.effective_slack_token
}

provider "onepassword" {}
