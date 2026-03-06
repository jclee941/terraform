locals {
  n8n_webhooks = {
    glitchtip-error = {
      url          = local.n8n_webhook_urls.glitchtip_error
      events       = ["push", "workflow_run", "check_run"]
      content_type = "json"
      active       = true
    }
    github-issue = {
      url          = local.n8n_webhook_urls.github_issue
      events       = ["issues", "issue_comment"]
      content_type = "json"
      active       = true
    }
    github-pr = {
      url          = local.n8n_webhook_urls.github_pr
      events       = ["pull_request", "pull_request_review", "push"]
      content_type = "json"
      active       = true
    }
  }

  default_repository_webhooks = {
    for repo_name, repo_cfg in local.repositories :
    repo_name => local.n8n_webhooks
    if !try(repo_cfg.archived, false)
  }

  repository_webhooks_effective = length(var.repository_webhooks) > 0 ? var.repository_webhooks : local.default_repository_webhooks

  repository_webhooks_flat = {
    for item in flatten([
      for repo_name, hooks in local.repository_webhooks_effective : [
        for hook_name, hook_cfg in hooks : {
          key          = "${repo_name}:${hook_name}"
          repository   = repo_name
          hook_name    = hook_name
          url          = hook_cfg.url
          events       = tolist(hook_cfg.events)
          content_type = try(hook_cfg.content_type, "json")
          active       = try(hook_cfg.active, true)
        }
      ]
    ]) : item.key => item
    if trimspace(item.url) != ""
  }
}

resource "github_repository_webhook" "webhooks" {
  for_each = local.repository_webhooks_flat

  repository = each.value.repository
  active     = each.value.active
  events     = each.value.events

  configuration {
    url          = each.value.url
    content_type = each.value.content_type
    insecure_ssl = var.webhook_insecure_ssl
    secret       = trimspace(var.webhook_secret) == "" ? null : var.webhook_secret
  }
}
