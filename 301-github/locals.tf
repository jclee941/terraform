locals {
  common_tags = {
    managed_by = "terraform"
    workspace  = "301-github"
    owner      = var.github_owner
  }

  naming = {
    prefix = "gh"
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
  }

  common_topics = [
    "infrastructure",
    "iac",
    "terraform",
  ]

  known_repositories = toset(var.known_repositories)
}
