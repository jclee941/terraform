import {
  for_each = var.enable_repository_imports ? local.repositories : {}
  to       = github_repository.repos[each.key]
  id       = each.key
}

import {
  for_each = var.enable_repository_imports ? local.security_repositories : {}
  to       = github_repository_dependabot_security_updates.repositories[each.key]
  id       = each.key
}
