locals {
  security_repositories = {
    for repo_name, repo_cfg in local.repositories :
    repo_name => {
      dependabot_enabled = lookup(var.security_dependabot_enabled, repo_name, true)
      scanning_tools     = tolist(lookup(var.security_code_scanning_tools, repo_name, ["CodeQL"]))
    }
    if !try(repo_cfg.archived, false)
  }
}

resource "github_repository_dependabot_security_updates" "repositories" {
  for_each = local.security_repositories

  repository = github_repository.repos[each.key].name
  enabled    = each.value.dependabot_enabled
}

resource "github_repository_ruleset" "code_scanning" {
  for_each = var.enable_repository_rulesets ? {
    for k, v in local.security_repositories : k => v
  } : {}

  name        = "code-scanning"
  repository  = github_repository.repos[each.key].name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~ALL"]
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
    required_code_scanning {
      dynamic "required_code_scanning_tool" {
        for_each = toset(each.value.scanning_tools)
        content {
          tool                      = required_code_scanning_tool.value
          alerts_threshold          = "errors"
          security_alerts_threshold = "high_or_higher"
        }
      }
    }
  }
}
