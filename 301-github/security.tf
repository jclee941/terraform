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
    if try(local.repositories[k].visibility, "public") != "private"
  } : {}

  name        = "required-code-scanning"
  repository  = github_repository.repos[each.key].name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  bypass_actors {
    actor_id    = 5 # RepositoryRole: admin
    actor_type  = "RepositoryRole"
    bypass_mode = "always"
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
