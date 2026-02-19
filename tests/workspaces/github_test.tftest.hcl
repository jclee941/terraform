# GitHub Workspace Variable Validation Tests
# Workspace: 301-github (GitHub Org, Repos, Teams, Branch Protection)
# Run: terraform test (from tests/workspaces/)

mock_provider "github" {}

override_data {
  target = data.terraform_remote_state.infra
  values = {
    outputs = {
      host_inventory = {}
      service_urls   = {}
    }
  }
}

override_data {
  target = data.github_user.owner
  values = {
    login = "qws941"
    id    = 12345
    name  = "test-user"
  }
}

override_data {
  target = data.github_repository.existing
  values = {
    name      = "terraform"
    full_name = "qws941/terraform"
    node_id   = "R_test"
    repo_id   = 99999
  }
}

# =============================================================================
# Positive Tests
# =============================================================================

run "test_valid_github_workspace" {
  command = plan

  module {
    source = "../../301-github"
  }

  variables {
    github_token = "test-token-placeholder"
    github_owner = "qws941"
  }

  assert {
    condition     = true
    error_message = "Valid github workspace should plan successfully"
  }
}

run "test_valid_github_owner_hyphenated" {
  command = plan

  module {
    source = "../../301-github"
  }

  variables {
    github_token = "test-token-placeholder"
    github_owner = "my-org-name"
  }

  assert {
    condition     = true
    error_message = "Hyphenated github_owner should be accepted"
  }
}

run "test_valid_github_owner_single_char" {
  command = plan

  module {
    source = "../../301-github"
  }

  variables {
    github_token = "test-token-placeholder"
    github_owner = "a"
  }

  assert {
    condition     = true
    error_message = "Single character github_owner should be accepted"
  }
}

run "test_valid_actions_allowed_all" {
  command = plan

  module {
    source = "../../301-github"
  }

  variables {
    github_token            = "test-token-placeholder"
    actions_allowed_actions = "all"
  }

  assert {
    condition     = true
    error_message = "actions_allowed_actions=all should be accepted"
  }
}

run "test_valid_actions_allowed_local_only" {
  command = plan

  module {
    source = "../../301-github"
  }

  variables {
    github_token            = "test-token-placeholder"
    actions_allowed_actions = "local_only"
  }

  assert {
    condition     = true
    error_message = "actions_allowed_actions=local_only should be accepted"
  }
}

run "test_valid_n8n_webhook_url" {
  command = plan

  module {
    source = "../../301-github"
  }

  variables {
    github_token                    = "test-token-placeholder"
    n8n_webhook_glitchtip_error_url = "https://n8n.jclee.me/webhook/glitchtip-error"
  }

  assert {
    condition     = true
    error_message = "Valid HTTPS webhook URL should be accepted"
  }
}

run "test_valid_n8n_webhook_url_empty" {
  command = plan

  module {
    source = "../../301-github"
  }

  variables {
    github_token                    = "test-token-placeholder"
    n8n_webhook_glitchtip_error_url = ""
  }

  assert {
    condition     = true
    error_message = "Empty webhook URL should be accepted (optional)"
  }
}

run "test_valid_secret_visibility_all" {
  command = plan

  module {
    source = "../../301-github"
  }

  variables {
    github_token                   = "test-token-placeholder"
    organization_secret_visibility = "all" # pragma: allowlist secret  # pragma: allowlist secret
  }

  assert {
    condition     = true
    error_message = "organization_secret_visibility=all should be accepted"
  }
}

# =============================================================================
# Negative Tests
# =============================================================================

# --- github_owner validation (GitHub username regex, max 39 chars) ---

run "test_invalid_github_owner_starts_with_hyphen" {
  command = plan

  module {
    source = "../../301-github"
  }

  variables {
    github_token = "test-token-placeholder"
    github_owner = "-invalid"
  }

  expect_failures = [
    var.github_owner,
  ]
}

run "test_invalid_github_owner_ends_with_hyphen" {
  command = plan

  module {
    source = "../../301-github"
  }

  variables {
    github_token = "test-token-placeholder"
    github_owner = "invalid-"
  }

  expect_failures = [
    var.github_owner,
  ]
}

run "test_invalid_github_owner_too_long" {
  command = plan

  module {
    source = "../../301-github"
  }

  variables {
    github_token = "test-token-placeholder"
    github_owner = "abcdefghijklmnopqrstuvwxyz1234567890abcd" # pragma: allowlist secret  # pragma: allowlist secret
  }

  expect_failures = [
    var.github_owner,
  ]
}

run "test_invalid_github_owner_underscore" {
  command = plan

  module {
    source = "../../301-github"
  }

  variables {
    github_token = "test-token-placeholder"
    github_owner = "invalid_name"
  }

  expect_failures = [
    var.github_owner,
  ]
}

# --- infra_domain validation (domain name regex) ---

run "test_invalid_infra_domain_starts_with_dot" {
  command = plan

  module {
    source = "../../301-github"
  }

  variables {
    github_token = "test-token-placeholder"
    infra_domain = ".jclee.me"
  }

  expect_failures = [
    var.infra_domain,
  ]
}

run "test_invalid_infra_domain_uppercase" {
  command = plan

  module {
    source = "../../301-github"
  }

  variables {
    github_token = "test-token-placeholder"
    infra_domain = "JCLEE.ME"
  }

  expect_failures = [
    var.infra_domain,
  ]
}

# --- actions_allowed_actions validation (enum) ---

run "test_invalid_actions_allowed_invalid_value" {
  command = plan

  module {
    source = "../../301-github"
  }

  variables {
    github_token            = "test-token-placeholder"
    actions_allowed_actions = "custom"
  }

  expect_failures = [
    var.actions_allowed_actions,
  ]
}

# --- actions_enabled_repositories validation (enum) ---

run "test_invalid_actions_enabled_repos_invalid_value" {
  command = plan

  module {
    source = "../../301-github"
  }

  variables {
    github_token                 = "test-token-placeholder"
    actions_enabled_repositories = "custom"
  }

  expect_failures = [
    var.actions_enabled_repositories,
  ]
}

# --- organization_secret_visibility validation (enum) ---

run "test_invalid_secret_visibility_invalid_value" {
  command = plan

  module {
    source = "../../301-github"
  }

  variables {
    github_token                   = "test-token-placeholder"
    organization_secret_visibility = "public" # pragma: allowlist secret  # pragma: allowlist secret
  }

  expect_failures = [
    var.organization_secret_visibility,
  ]
}

# --- n8n_webhook URLs validation (empty or HTTP(S)) ---

run "test_invalid_n8n_webhook_glitchtip_no_protocol" {
  command = plan

  module {
    source = "../../301-github"
  }

  variables {
    github_token                    = "test-token-placeholder"
    n8n_webhook_glitchtip_error_url = "n8n.jclee.me/webhook/glitchtip"
  }

  expect_failures = [
    var.n8n_webhook_glitchtip_error_url,
  ]
}

run "test_invalid_n8n_webhook_grafana_ftp" {
  command = plan

  module {
    source = "../../301-github"
  }

  variables {
    github_token                  = "test-token-placeholder"
    n8n_webhook_grafana_alert_url = "ftp://n8n.jclee.me/webhook/grafana"
  }

  expect_failures = [
    var.n8n_webhook_grafana_alert_url,
  ]
}

run "test_invalid_n8n_webhook_issue_no_protocol" {
  command = plan

  module {
    source = "../../301-github"
  }

  variables {
    github_token                 = "test-token-placeholder"
    n8n_webhook_github_issue_url = "n8n.jclee.me/webhook/github-issue"
  }

  expect_failures = [
    var.n8n_webhook_github_issue_url,
  ]
}

run "test_invalid_n8n_webhook_pr_no_protocol" {
  command = plan

  module {
    source = "../../301-github"
  }

  variables {
    github_token              = "test-token-placeholder"
    n8n_webhook_github_pr_url = "n8n.jclee.me/webhook/github-pr"
  }

  expect_failures = [
    var.n8n_webhook_github_pr_url,
  ]
}
