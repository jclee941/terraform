locals {
  ruleset_repositories = {
    for repo_name, repo_cfg in local.repositories :
    repo_name => {
      protection          = try(repo_cfg.protection, "minimal")
      extra_status_checks = try(repo_cfg.extra_status_checks, [])
    }
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
      status_checks                     = ["Validate Changes"]
    }
    standard = {
      required_approving_review_count   = 1
      require_code_owner_review         = false
      dismiss_stale_reviews_on_push     = true
      require_last_push_approval        = true
      required_review_thread_resolution = true
      required_linear_history           = true
      required_signatures               = false
      creation                          = true
      deletion                          = true
      non_fast_forward                  = true
      status_checks                     = ["Validate Changes"]
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
  for_each = var.enable_repository_rulesets ? local.ruleset_repositories : {}

  name        = "default-branch-protection"
  repository  = github_repository.repos[each.key].name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  dynamic "bypass_actors" {
    for_each = var.ruleset_bypass_actors
    content {
      actor_id    = bypass_actors.value.actor_id
      actor_type  = bypass_actors.value.actor_type
      bypass_mode = bypass_actors.value.bypass_mode
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
      allowed_merge_methods             = local.repository_defaults.allowed_merge_methods
    }

    dynamic "required_status_checks" {
      for_each = length(distinct(concat(
        local.protection_profiles[try(each.value.protection, "minimal")].status_checks,
        try(each.value.extra_status_checks, [])
      ))) > 0 ? [1] : []
      content {
        strict_required_status_checks_policy = true
        dynamic "required_check" {
          for_each = toset(distinct(concat(
            local.protection_profiles[try(each.value.protection, "minimal")].status_checks,
            try(each.value.extra_status_checks, [])
          )))
          content {
            context = required_check.value
          }
        }
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

  dynamic "bypass_actors" {
    for_each = var.ruleset_bypass_actors
    content {
      actor_id    = bypass_actors.value.actor_id
      actor_type  = bypass_actors.value.actor_type
      bypass_mode = bypass_actors.value.bypass_mode
    }
  }

  rules {
    creation         = true
    update           = true
    deletion         = true
    non_fast_forward = true

  }
}
