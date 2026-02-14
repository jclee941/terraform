locals {
  ruleset_repositories = {
    for repo_name, repo_cfg in local.repositories :
    repo_name => repo_cfg
    if !try(repo_cfg.archived, false)
  }
}

resource "github_repository_ruleset" "branch" {
  for_each = var.enable_repository_rulesets ? local.ruleset_repositories : {}

  name        = "default-branch-rules"
  repository  = github_repository.repos[each.key].name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  rules {
    creation                = true
    update                  = true
    deletion                = true
    non_fast_forward        = true
    required_linear_history = true

    pull_request {
      dismiss_stale_reviews_on_push     = true
      require_code_owner_review         = false
      require_last_push_approval        = false
      required_approving_review_count   = 1
      required_review_thread_resolution = true
      allowed_merge_methods             = ["squash", "rebase"]
    }

    required_status_checks {
      strict_required_status_checks_policy = true

      required_check {
        context = "pr-review"
      }
    }

    dynamic "branch_name_pattern" {
      for_each = var.enable_enterprise_branch_name_pattern ? [1] : []
      content {
        name     = "conventional-branch-names"
        operator = "regex"
        pattern  = "^(main|master|develop|feature\\/.*|fix\\/.*|chore\\/.*|docs\\/.*)$"
        negate   = false
      }
    }
  }
}

resource "github_repository_ruleset" "tags" {
  for_each = var.enable_repository_rulesets ? local.ruleset_repositories : {}

  name        = "tag-protection"
  repository  = github_repository.repos[each.key].name
  target      = "tag"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["refs/tags/v*"]
      exclude = []
    }
  }

  rules {
    creation         = true
    update           = true
    deletion         = true
    non_fast_forward = true
  }
}
