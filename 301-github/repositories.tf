locals {
  repositories = {
    terraform = {
      description    = "Multi-provider infrastructure as code monorepo"
      visibility     = "public"
      topics         = ["homelab", "proxmox", "cloudflare", "bazel"]
      archived       = false
      default_branch = "master"
    }
    proxmox = {
      description    = "Proxmox infrastructure and automation workspace"
      visibility     = "public"
      topics         = ["proxmox", "homelab", "terraform"]
      archived       = false
      default_branch = "main"
    }
    github-iac-template = {
      description    = "Template repository for GitHub infrastructure management"
      visibility     = "private"
      topics         = ["github", "automation", "template"]
      archived       = false
      default_branch = "main"
    }
  }
}

resource "github_repository" "repos" {
  for_each = local.repositories

  name        = each.key
  description = each.value.description
  visibility  = try(each.value.visibility, local.repository_defaults.visibility)

  topics = distinct(concat(local.common_topics, try(each.value.topics, [])))

  has_issues             = local.repository_defaults.has_issues
  has_wiki               = local.repository_defaults.has_wiki
  has_projects           = local.repository_defaults.has_projects
  delete_branch_on_merge = local.repository_defaults.delete_branch_on_merge
  allow_squash_merge     = local.repository_defaults.allow_squash_merge
  allow_merge_commit     = local.repository_defaults.allow_merge_commit
  allow_rebase_merge     = local.repository_defaults.allow_rebase_merge
  allow_auto_merge       = local.repository_defaults.allow_auto_merge

  vulnerability_alerts        = local.repository_defaults.vulnerability_alerts
  web_commit_signoff_required = local.repository_defaults.web_commit_signoff_required
  archived                    = try(each.value.archived, local.repository_defaults.archived)
  auto_init                   = true
}
