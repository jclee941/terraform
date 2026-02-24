# ──────────────────────────────────────────────────────────────────────────────
# Standard Issue Labels — applied uniformly across all active repositories
# ──────────────────────────────────────────────────────────────────────────────

locals {
  standard_labels = {
    bug            = { color = "d73a4a", description = "Something isn't working" }
    enhancement    = { color = "a2eeef", description = "New feature or request" }
    documentation  = { color = "0075ca", description = "Improvements or additions to documentation" }
    dependencies   = { color = "0366d6", description = "Pull requests that update a dependency file" }
    automated      = { color = "6f42c1", description = "Automated pull requests" }
    terraform      = { color = "844fba", description = "Terraform-related changes" }
    security       = { color = "e4e669", description = "Security-related issue or fix" }
    infrastructure = { color = "006b75", description = "Infrastructure changes" }
    ci             = { color = "fbca04", description = "CI/CD pipeline changes" }
    keep-open      = { color = "ffffff", description = "Exempt from stale bot" }
    pinned         = { color = "ededed", description = "Pinned issue, exempt from stale" }
  }

  # Cross-product: each active repo × each standard label
  repo_labels = {
    for pair in setproduct(keys(local.repositories), keys(local.standard_labels)) :
    "${pair[0]}/${pair[1]}" => {
      repository  = pair[0]
      name        = pair[1]
      color       = local.standard_labels[pair[1]].color
      description = local.standard_labels[pair[1]].description
    }
    if !try(local.repositories[pair[0]].archived, false)
  }
}

resource "github_issue_label" "standard" {
  for_each = local.repo_labels

  repository  = github_repository.repos[each.value.repository].name
  name        = each.value.name
  color       = each.value.color
  description = each.value.description
}
