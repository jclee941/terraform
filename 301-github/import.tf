import {
  for_each = {
    for k, v in local.repositories : k => v
    if var.enable_repository_imports
  }
  to = github_repository.repos[each.key]
  id = each.key
}

import {
  for_each = {
    for k, v in local.security_repositories : k => v
    if var.enable_repository_imports
  }
  to = github_repository_dependabot_security_updates.repositories[each.key]
  id = each.key
}
