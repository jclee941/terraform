locals {
  branch_protection_profiles = {
    strict = {
      enforce_admins                  = true
      status_checks_strict            = true
      required_status_checks_contexts = ["terraform / plan", "terraform / validate", "pr-review"]
      dismiss_stale_reviews           = true
      require_code_owner_reviews      = true
      required_approving_review_count = 2
      require_last_push_approval      = true
      require_linear_history          = true
      require_signed_commits          = true
      require_conversation_resolution = true
      blocks_creations                = true
      push_allowances                 = []
    }
    standard = {
      enforce_admins                  = true
      status_checks_strict            = true
      required_status_checks_contexts = ["terraform / plan", "pr-review"]
      dismiss_stale_reviews           = true
      require_code_owner_reviews      = false
      required_approving_review_count = 1
      require_last_push_approval      = false
      require_linear_history          = true
      require_signed_commits          = false
      require_conversation_resolution = true
      blocks_creations                = true
      push_allowances                 = []
    }
    minimal = {
      enforce_admins                  = false
      status_checks_strict            = false
      required_status_checks_contexts = []
      dismiss_stale_reviews           = false
      require_code_owner_reviews      = false
      required_approving_review_count = 1
      require_last_push_approval      = false
      require_linear_history          = false
      require_signed_commits          = false
      require_conversation_resolution = false
      blocks_creations                = false
      push_allowances                 = []
    }
  }

  branch_protection_levels = {
    terraform           = "strict"
    proxmox             = "standard"
    github-iac-template = "minimal"
  }

  branch_protection = {
    for repo_name, repo_cfg in local.repositories :
    repo_name => merge(
      local.branch_protection_profiles[lookup(local.branch_protection_levels, repo_name, "standard")],
      {
        pattern = try(repo_cfg.default_branch, "main")
      }
    )
    if !try(repo_cfg.archived, false)
  }
}

resource "github_branch_protection" "branches" {
  for_each = local.branch_protection

  repository_id                   = github_repository.repos[each.key].name
  pattern                         = each.value.pattern
  enforce_admins                  = each.value.enforce_admins
  required_linear_history         = each.value.require_linear_history
  require_signed_commits          = each.value.require_signed_commits
  require_conversation_resolution = each.value.require_conversation_resolution
  allows_force_pushes             = false
  allows_deletions                = false

  required_status_checks {
    strict   = each.value.status_checks_strict
    contexts = each.value.required_status_checks_contexts
  }

  required_pull_request_reviews {
    dismiss_stale_reviews           = each.value.dismiss_stale_reviews
    require_code_owner_reviews      = each.value.require_code_owner_reviews
    required_approving_review_count = each.value.required_approving_review_count
    require_last_push_approval      = each.value.require_last_push_approval
  }

  restrict_pushes {
    blocks_creations = each.value.blocks_creations
    push_allowances  = each.value.push_allowances
  }
}
