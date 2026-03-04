variable "github_token" {
  description = "GitHub personal access token (optional if provided via 1Password)"
  type        = string
  sensitive   = true
  default     = ""

  validation {
    condition     = var.github_token == "" || can(regex("^(ghp_|github_pat_)", var.github_token))
    error_message = "github_token must be empty or start with 'ghp_' (classic) or 'github_pat_' (fine-grained)."
  }
}

variable "github_owner" {
  description = "GitHub organization or user"
  type        = string
  default     = "qws941-lab"

  validation {
    condition     = can(regex("^[a-zA-Z0-9]([a-zA-Z0-9-]{0,37}[a-zA-Z0-9])?$", var.github_owner))
    error_message = "github_owner must be a valid GitHub username (alphanumeric and hyphens, max 39 chars)."
  }
}

variable "manage_as_organization" {
  description = "Enable organization-only resources (teams, org actions, runner groups)."
  type        = bool
  default     = true
}

variable "infra_domain" {
  description = "Infrastructure domain used to derive service URLs (e.g., mcphub.{domain})."
  type        = string
  default     = "jclee.me"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]+[a-z0-9]$", var.infra_domain))
    error_message = "infra_domain must be a valid domain name."
  }
}

variable "enable_infra_actions_variables" {
  description = "Populate GitHub Actions variables with infrastructure endpoints from remote state."
  type        = bool
  default     = false
}


variable "actions_allowed_actions" {
  description = "Organization-level allowed actions policy: all, local_only, selected."
  type        = string
  default     = "selected"

  validation {
    condition     = contains(["all", "local_only", "selected"], var.actions_allowed_actions)
    error_message = "actions_allowed_actions must be one of: all, local_only, selected."
  }
}

variable "actions_allowed_patterns" {
  description = "Allowed actions patterns when actions_allowed_actions is selected."
  type        = list(string)
  default = [
    "actions/checkout@*",
    "actions/cache@*",
    "actions/setup-*",
    "anomalyco/opencode/*",
    "cloudflare/wrangler-action@*",
    "release-drafter/release-drafter@*",
    "amannn/action-semantic-pull-request@*",
    "dessant/lock-threads@*",
    "CodelyTV/pr-size-labeler@*",
    "terraform-docs/gh-actions@*",
  ]
}

variable "actions_enabled_repositories" {
  description = "Organization-level enabled repositories policy: all, none, selected."
  type        = string
  default     = "selected"

  validation {
    condition     = contains(["all", "none", "selected"], var.actions_enabled_repositories)
    error_message = "actions_enabled_repositories must be one of: all, none, selected."
  }
}

variable "actions_enabled_repositories_selected" {
  description = "Selected repositories for org Actions enablement when policy is selected."
  type        = set(string)
  default = [
    "terraform",
  ]
}

variable "organization_actions_secrets" {
  description = "Organization Actions secrets as a map(secret_name => plaintext_value)."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "organization_secret_visibility" {
  description = "Visibility for organization-level secrets and variables: all, private, selected."
  type        = string
  default     = "private"

  validation {
    condition     = contains(["all", "private", "selected"], var.organization_secret_visibility)
    error_message = "organization_secret_visibility must be one of: all, private, selected."
  }
}


variable "organization_actions_variables" {
  description = "Organization Actions variables as a map(variable_name => value)."
  type        = map(string)
  default     = {}
}

variable "organization_variable_selected_repositories" {
  description = "Selected repositories for each organization variable when visibility is selected."
  type        = map(set(string))
  default     = {}
}

variable "repository_actions_secrets" {
  description = "Repository Actions secrets as map(repo => map(secret_name => plaintext_value))."
  type        = map(map(string))
  default     = {}
  sensitive   = true
}

variable "repository_actions_variables" {
  description = "Repository Actions variables as map(repo => map(variable_name => value))."
  type        = map(map(string))
  default     = {}
}

variable "runner_groups" {
  description = "Organization runner groups keyed by name."
  type = map(object({
    visibility                 = optional(string, "selected")
    allows_public_repositories = optional(bool, false)
    restricted_to_workflows    = optional(bool, false)
    selected_workflows         = optional(list(string), [])
    selected_repositories      = optional(set(string), [])
  }))
  default = {
    homelab = {
      visibility                 = "all"
      allows_public_repositories = true
    }
  }
}

variable "n8n_webhook_glitchtip_error_url" {
  description = "n8n webhook URL for GlitchTip error workflows."
  type        = string
  default     = ""

  validation {
    condition     = var.n8n_webhook_glitchtip_error_url == "" || can(regex("^https?://", var.n8n_webhook_glitchtip_error_url))
    error_message = "n8n_webhook_glitchtip_error_url must be empty or a valid HTTP(S) URL."
  }
}

variable "n8n_webhook_grafana_alert_url" {
  description = "n8n webhook URL for Grafana alerts."
  type        = string
  default     = ""

  validation {
    condition     = var.n8n_webhook_grafana_alert_url == "" || can(regex("^https?://", var.n8n_webhook_grafana_alert_url))
    error_message = "n8n_webhook_grafana_alert_url must be empty or a valid HTTP(S) URL."
  }
}

variable "n8n_webhook_github_issue_url" {
  description = "n8n webhook URL for GitHub issue automation."
  type        = string
  default     = ""

  validation {
    condition     = var.n8n_webhook_github_issue_url == "" || can(regex("^https?://", var.n8n_webhook_github_issue_url))
    error_message = "n8n_webhook_github_issue_url must be empty or a valid HTTP(S) URL."
  }
}

variable "n8n_webhook_github_pr_url" {
  description = "n8n webhook URL for GitHub PR automation."
  type        = string
  default     = ""

  validation {
    condition     = var.n8n_webhook_github_pr_url == "" || can(regex("^https?://", var.n8n_webhook_github_pr_url))
    error_message = "n8n_webhook_github_pr_url must be empty or a valid HTTP(S) URL."
  }
}

variable "webhook_secret" {
  description = "Shared secret used by repository webhooks."
  type        = string
  default     = ""
  sensitive   = true
}

variable "webhook_insecure_ssl" {
  description = "Whether to allow insecure SSL for webhook delivery."
  type        = bool
  default     = false
}

variable "repository_webhooks" {
  description = "Repository webhooks as map(repo => map(webhook_name => webhook_config))."
  type = map(map(object({
    url          = string
    events       = set(string)
    content_type = optional(string, "json")
    active       = optional(bool, true)
  })))
  default = {}
}

variable "teams" {
  description = "Organization teams keyed by team slug key."
  type = map(object({
    name                 = string
    description          = optional(string, "")
    privacy              = optional(string, "closed")
    notification_setting = optional(string, "notifications_enabled")
  }))
  default = {
    platform = {
      name        = "platform"
      description = "Platform engineering team"
      privacy     = "closed"
    }
  }
}

variable "team_memberships" {
  description = "Team memberships as map(team_key => map(username => role))."
  type        = map(map(string))
  default     = {}
}

variable "team_repository_access" {
  description = "Team repo access as map(team_key => map(repo_name => permission))."
  type        = map(map(string))
  default     = {}
}

variable "repository_deploy_keys" {
  description = "Deploy keys as map(repo => map(key_title => { key, read_only }))."
  type = map(map(object({
    key       = string
    read_only = bool
  })))
  default   = {}
  sensitive = true
}

variable "repository_environments" {
  description = "Environment definitions as map(repo => map(environment => config))."
  type = map(map(object({
    wait_timer             = optional(number, 0)
    can_admins_bypass      = optional(bool, true)
    prevent_self_review    = optional(bool, true)
    protected_branches     = optional(bool, true)
    custom_branch_policies = optional(bool, false)
    reviewer_user_ids      = optional(set(number), [])
    reviewer_team_ids      = optional(set(number), [])
  })))
  default = {
    terraform = {
      production = {
        wait_timer             = 0
        can_admins_bypass      = true
        prevent_self_review    = false
        protected_branches     = true
        custom_branch_policies = false
      }
    }
  }
}

variable "repository_environment_secrets" {
  description = "Environment secrets as map(repo => map(environment => map(secret_name => plaintext_value)))."
  type        = map(map(map(string)))
  default     = {}
  sensitive   = true
}

variable "repository_environment_variables" {
  description = "Environment variables as map(repo => map(environment => map(variable_name => value)))."
  type        = map(map(map(string)))
  default     = {}
}

variable "security_dependabot_enabled" {
  description = "Enable Dependabot security updates by repository."
  type        = map(bool)
  default = {
    blacklist = true
    hycu_fsds = true
    propose   = true
    resume    = true
    splunk    = true
    terraform = true
    tmux      = true
    youtube   = true
  }
}

variable "security_code_scanning_tools" {
  description = "Code scanning tools required by ruleset for each repository."
  type        = map(set(string))
  default = {
    blacklist = ["CodeQL"]
    hycu_fsds = ["CodeQL"]
    propose   = ["CodeQL"]
    resume    = ["CodeQL"]
    splunk    = ["CodeQL"]
    terraform = ["CodeQL"]
    tmux      = ["CodeQL"]
    youtube   = ["CodeQL"]
  }
}

variable "enable_repository_rulesets" {
  description = "Enable repository rulesets management."
  type        = bool
  default     = true
}

variable "ruleset_bypass_actors" {
  description = "Bypass actors for repository rulesets (admin, integrations, etc.)."
  type = list(object({
    actor_id    = number
    actor_type  = string
    bypass_mode = optional(string, "always")
  }))
  default = [
    {
      actor_id   = 5 # RepositoryRole: admin
      actor_type = "RepositoryRole"
    },
    {
      actor_id   = 1144995 # Integration: OpenAI Codex
      actor_type = "Integration"
    },
    {
      actor_id   = 1549082 # Integration: OpenCode
      actor_type = "Integration"
    },
  ]
}


variable "enable_repository_imports" {
  description = "Enable import blocks for existing repositories."
  type        = bool
  default     = false
}

variable "enable_codeowners_management" {
  description = "Enable Terraform-managed CODEOWNERS files. Disable when rulesets block direct commits."
  type        = bool
  default     = false
}

variable "onepassword_vault_name" {
  description = "1Password vault name for secret lookups"
  type        = string
  default     = "homelab"
}
