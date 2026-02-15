locals {
  ruleset_repositories = {
    for repo_name, repo_cfg in local.repositories :
    repo_name => repo_cfg
    if !try(repo_cfg.archived, false)
  }

  protection_profiles = {
    strict = {
      required_approving_review_count   = 2
      require_code_owner_review         = true
      dismiss_stale_reviews_on_push     = true
      require_last_push_approval        = true
      required_review_thread_resolution = true
      required_linear_history           = true
      required_signatures               = true
      creation                          = true
      deletion                          = true
      non_fast_forward                  = true
      status_checks                     = ["pr-review"]
    }
    standard = {
      required_approving_review_count   = 1
      require_code_owner_review         = false
      dismiss_stale_reviews_on_push     = true
      require_last_push_approval        = false
      required_review_thread_resolution = true
      required_linear_history           = true
      required_signatures               = false
      creation                          = true
      deletion                          = true
      non_fast_forward                  = true
      status_checks                     = ["pr-review"]
    }
    minimal = {
      required_approving_review_count   = 1
      require_code_owner_review         = false
      dismiss_stale_reviews_on_push     = false
      require_last_push_approval        = false
      required_review_thread_resolution = false
      required_linear_history           = false
      required_signatures               = false
      creation                          = false
      deletion                          = true
      non_fast_forward                  = true
      status_checks                     = []
    }
  }
}

resource "github_repository_ruleset" "branch" {
  for_each = var.enable_repository_rulesets ? local.ruleset_repositories : tomap({})

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
    creation                = local.protection_profiles[try(each.value.protection, "minimal")].creation
    update                  = true
    deletion                = local.protection_profiles[try(each.value.protection, "minimal")].deletion
    non_fast_forward        = local.protection_profiles[try(each.value.protection, "minimal")].non_fast_forward
    required_linear_history = local.protection_profiles[try(each.value.protection, "minimal")].required_linear_history
    required_signatures     = local.protection_profiles[try(each.value.protection, "minimal")].required_signatures

    pull_request {
      dismiss_stale_reviews_on_push     = local.protection_profiles[try(each.value.protection, "minimal")].dismiss_stale_reviews_on_push
      require_code_owner_review         = local.protection_profiles[try(each.value.protection, "minimal")].require_code_owner_review
      require_last_push_approval        = local.protection_profiles[try(each.value.protection, "minimal")].require_last_push_approval
      required_approving_review_count   = local.protection_profiles[try(each.value.protection, "minimal")].required_approving_review_count
      required_review_thread_resolution = local.protection_profiles[try(each.value.protection, "minimal")].required_review_thread_resolution
      allowed_merge_methods             = ["squash", "rebase"]
    }

    dynamic "required_status_checks" {
      for_each = length(local.protection_profiles[try(each.value.protection, "minimal")].status_checks) > 0 ? [1] : []
      content {
        strict_required_status_checks_policy = true
        dynamic "required_check" {
          for_each = toset(local.protection_profiles[try(each.value.protection, "minimal")].status_checks)
          content {
            context = required_check.value
          }
        }
      }
    }
  }
}

resource "github_repository_ruleset" "tags" {
  for_each = var.enable_repository_rulesets ? local.ruleset_repositories : tomap({})

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
