# ──────────────────────────────────────────────────────────────────────────────
# Standard Issue Labels — canonical set from .github SSoT (scripts/labels.yml)
# Applied uniformly across all active (non-archived) repositories
# ──────────────────────────────────────────────────────────────────────────────

locals {
  standard_labels = {
    # Type labels
    "type:bug"      = { color = "d73a4a", description = "Something isn't working" }
    "type:feature"  = { color = "a2eeef", description = "New feature or request" }
    "type:docs"     = { color = "0075ca", description = "Documentation improvements" }
    "type:refactor" = { color = "d4c5f9", description = "Code refactoring (no functional change)" }
    "type:ci"       = { color = "e8d44d", description = "CI/CD and workflow changes" }
    "type:chore"    = { color = "ededed", description = "Maintenance and housekeeping" }
    "type:security" = { color = "e11d48", description = "Security-related changes" }
    "type:test"     = { color = "bfd4f2", description = "Test additions or updates" }
    "type:infra"    = { color = "f9a825", description = "Infrastructure changes (Terraform, deployment)" }

    # Priority labels
    "priority:critical" = { color = "b60205", description = "Must be addressed immediately" }
    "priority:high"     = { color = "d93f0b", description = "Should be addressed soon" }
    "priority:medium"   = { color = "fbca04", description = "Normal priority" }
    "priority:low"      = { color = "0e8a16", description = "Nice to have, no rush" }

    # Status labels
    "status:blocked"      = { color = "b60205", description = "Blocked by external dependency" }
    "status:in-progress"  = { color = "0052cc", description = "Currently being worked on" }
    "status:needs-review" = { color = "006b75", description = "Ready for review" }
    "status:wontfix"      = { color = "ffffff", description = "Will not be addressed" }
    "status:duplicate"    = { color = "cfd3d7", description = "Duplicate of another issue" }

    # Size labels (auto-applied by pr-size.yml workflow)
    "size/xs" = { color = "3cbf00", description = "Extra small PR (≤10 lines)" }
    "size/s"  = { color = "5d9801", description = "Small PR (≤100 lines)" }
    "size/m"  = { color = "7f7203", description = "Medium PR (≤200 lines)" }
    "size/l"  = { color = "a14c05", description = "Large PR (≤500 lines)" }
    "size/xl" = { color = "c32607", description = "Extra large PR (>500 lines)" }

    # Automation labels
    sync         = { color = "0e8a16", description = "File sync PR from .github SSoT" }
    "auto-merge" = { color = "0e8a16", description = "PR approved for automatic merge" }
    codex        = { color = "7057ff", description = "Codex AI automation trigger" }
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
