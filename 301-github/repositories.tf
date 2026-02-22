locals {
  repositories = {
    terraform = {
      description         = "Multi-provider infrastructure as code monorepo"
      visibility          = "private"
      topics              = ["homelab", "proxmox", "cloudflare", "bazel"]
      archived            = false
      default_branch      = "master"
      protection          = "strict"
      extra_status_checks = ["Terraform Plan"]
    }
    blacklist = {
      description    = "Blacklist management application"
      visibility     = "public"
      topics         = ["nodejs", "javascript"]
      archived       = false
      default_branch = "master"
      protection     = "standard"
    }
    safework2 = {
      description    = "SafeWork platform v2"
      visibility     = "private"
      topics         = ["typescript", "nextjs"]
      archived       = false
      default_branch = "master"
      protection     = "standard"
    }
    propose = {
      description    = "Proposal management tool"
      visibility     = "private"
      topics         = ["typescript"]
      archived       = false
      default_branch = "master"
      protection     = "standard"
    }
    resume = {
      description    = "Personal resume and portfolio"
      visibility     = "public"
      topics         = ["javascript", "portfolio"]
      archived       = false
      default_branch = "master"
      protection     = "minimal"
    }
    hycu_fsds = {
      description    = "HYCU FSDS autonomous driving"
      visibility     = "public"
      topics         = ["python", "autonomous-driving"]
      archived       = false
      default_branch = "master"
      protection     = "standard"
    }
    youtube = {
      description    = "YouTube automation tools"
      visibility     = "public"
      topics         = ["python", "youtube"]
      archived       = false
      default_branch = "master"
      protection     = "minimal"
    }
    splunk = {
      description    = "Splunk apps and configurations"
      visibility     = "public"
      topics         = ["python", "splunk"]
      archived       = false
      default_branch = "master"
      protection     = "minimal"
    }
    tmux = {
      description    = "Tmux configuration"
      visibility     = "public"
      topics         = ["shell", "tmux"]
      archived       = false
      default_branch = "master"
      protection     = "minimal"
    }
  }

}

resource "github_repository" "repos" {
  for_each = local.repositories

  name        = each.key
  description = each.value.description
  visibility  = try(each.value.visibility, local.repository_defaults.visibility)

  topics = distinct(concat(
    local.common_topics_by_repository[each.key],
    try(each.value.topics, [])
  ))

  has_issues             = local.repository_defaults.has_issues
  has_wiki               = local.repository_defaults.has_wiki
  has_projects           = local.repository_defaults.has_projects
  delete_branch_on_merge = local.repository_defaults.delete_branch_on_merge
  allow_squash_merge     = local.repository_defaults.allow_squash_merge
  allow_merge_commit     = local.repository_defaults.allow_merge_commit
  allow_rebase_merge     = local.repository_defaults.allow_rebase_merge
  allow_auto_merge       = local.repository_defaults.allow_auto_merge
  is_template            = try(each.value.is_template, false)

  squash_merge_commit_title   = "PR_TITLE"
  squash_merge_commit_message = "PR_BODY"

  vulnerability_alerts        = try(each.value.archived, false) ? false : local.repository_defaults.vulnerability_alerts
  web_commit_signoff_required = local.repository_defaults.web_commit_signoff_required
  archived                    = try(each.value.archived, false)

  lifecycle {
    ignore_changes = [auto_init, pages, template]
  }
}
