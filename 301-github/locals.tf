locals {
  infra_hosts      = try(data.terraform_remote_state.infra.outputs.host_inventory, {})
  service_urls     = try(data.terraform_remote_state.infra.outputs.service_urls, {})
  infra_domain     = var.infra_domain
  n8n_webhook_base = "https://mcphub.${local.infra_domain}"

  n8n_webhook_urls = {
    glitchtip_error = coalesce(var.n8n_webhook_glitchtip_error_url, "${local.n8n_webhook_base}/webhook/glitchtip-error")
    github_issue    = coalesce(var.n8n_webhook_github_issue_url, "${local.n8n_webhook_base}/webhook/github-issue")
    github_pr       = coalesce(var.n8n_webhook_github_pr_url, "${local.n8n_webhook_base}/webhook/github-pr")
  }

  infra_actions_variables = {
    PROXMOX_ENDPOINT = "https://pve.${local.infra_domain}:8006"
    GRAFANA_URL      = try(local.service_urls.grafana_url, "")
    N8N_URL          = try(local.service_urls.n8n_url, "")
  }


  repository_defaults = {
    visibility                  = "public"
    has_issues                  = true
    has_wiki                    = false
    has_projects                = false
    has_downloads               = false
    allow_squash_merge          = true
    allow_merge_commit          = false
    allow_rebase_merge          = true
    delete_branch_on_merge      = true
    vulnerability_alerts        = true
    archived                    = false
    allow_auto_merge            = true
    web_commit_signoff_required = false
    squash_merge_commit_title   = "PR_TITLE"
    squash_merge_commit_message = "PR_BODY"
    allowed_merge_methods       = ["squash", "rebase"]
  }

  common_topics = []

  common_topics_by_repository = {
    for repo_name, repo_cfg in local.repositories :
    repo_name => (try(repo_cfg.archived, false) ? [] : local.common_topics)
  }
}
