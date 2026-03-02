locals {
  repositories = {
    # --- Infrastructure ---
    terraform = {
      description         = "Multi-provider infrastructure as code monorepo"
      visibility          = "private"
      topics              = ["homelab", "proxmox", "cloudflare", "bazel", "infrastructure", "iac", "terraform"]
      default_branch      = "master"
      protection          = "strict"
      extra_status_checks = ["Terraform Plan"]
    }

    # --- Applications ---
    blacklist = {
      description    = "Blacklist management application"
      visibility     = "public"
      topics         = ["nodejs", "javascript"]
      default_branch = "master"
      protection     = "standard"
    }
    safetywallet = {
      description    = "SafetyWallet monorepo"
      visibility     = "public"
      topics         = ["typescript", "nextjs"]
      default_branch = "master"
      protection     = "standard"
    }

    # --- Tools & Config ---
    opencode = {
      description    = "OpenCode home workspace — agent runtime configuration, skills, and operating policies"
      visibility     = "private"
      topics         = ["opencode", "ai-agent", "configuration"]
      default_branch = "master"
      protection     = "standard"
    }
    qws941 = {
      description    = "GitHub profile README"
      visibility     = "public"
      topics         = ["profile"]
      default_branch = "master"
      protection     = "minimal"
    }
    tmux = {
      description    = "Tmux configuration"
      visibility     = "public"
      topics         = ["shell", "tmux"]
      default_branch = "master"
      protection     = "minimal"
    }
    slack-opencode-bridge = {
      description    = "Slack ↔ OpenCode bridge for notifications and approvals"
      visibility     = "public"
      topics         = ["slack", "opencode", "integration"]
      default_branch = "master"
      protection     = "standard"
    }
    ".github" = {
      description    = "GitHub community health files — reusable workflows, issue templates, and governance"
      visibility     = "public"
      topics         = ["github", "governance", "ci-cd"]
      default_branch = "master"
      protection     = "strict"
    }

    # --- Data & ML Competitions ---
    aimo3-prize = {
      description    = "AIMO Progress Prize 3 - Math Olympiad Solver"
      visibility     = "private"
      topics         = ["python", "kaggle", "math"]
      default_branch = "master"
      protection     = "minimal"
    }
    march-mania = {
      description    = "NCAA March Machine Learning Mania 2026 tournament prediction"
      visibility     = "private"
      topics         = ["python", "kaggle", "machine-learning"]
      default_branch = "master"
      protection     = "minimal"
    }
    kaggle-playground = {
      description    = "Kaggle Playground Series S6 tabular competitions"
      visibility     = "private"
      topics         = ["python", "kaggle", "tabular"]
      default_branch = "master"
      protection     = "minimal"
    }
    arc-prize = {
      description    = "ARC Prize 2025 — abstract reasoning grid solver"
      visibility     = "private"
      topics         = ["python", "kaggle", "reasoning"]
      default_branch = "master"
      protection     = "minimal"
    }
    agents-league = {
      description    = "Multi-agent reasoning for Microsoft Agents League — Planner→Solver→Verifier pipeline"
      visibility     = "private"
      topics         = ["python", "kaggle", "multi-agent"]
      default_branch = "master"
      protection     = "minimal"
    }

    # --- Legacy (public, maintained) ---
    propose = {
      description    = "Proposal management tool"
      visibility     = "private"
      topics         = ["typescript"]
      default_branch = "master"
      protection     = "standard"
    }
    resume = {
      description    = "Personal resume and portfolio"
      visibility     = "public"
      topics         = ["javascript", "portfolio"]
      default_branch = "master"
      protection     = "minimal"
    }
    hycu_fsds = {
      description    = "HYCU FSDS autonomous driving"
      visibility     = "public"
      topics         = ["python", "autonomous-driving"]
      default_branch = "master"
      protection     = "standard"
    }
    youtube = {
      description    = "YouTube automation tools"
      visibility     = "private"
      topics         = ["python", "youtube"]
      default_branch = "master"
      protection     = "minimal"
    }
    splunk = {
      description    = "Splunk apps and configurations"
      visibility     = "public"
      topics         = ["python", "splunk"]
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
