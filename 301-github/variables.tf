variable "github_token" {
  description = "GitHub personal access token"
  type        = string
  sensitive   = true
}

variable "github_owner" {
  description = "GitHub organization or user"
  type        = string
  default     = "qws941"

  validation {
    condition     = can(regex("^[a-zA-Z0-9]([a-zA-Z0-9-]{0,37}[a-zA-Z0-9])?$", var.github_owner))
    error_message = "github_owner must be a valid GitHub username (alphanumeric and hyphens, max 39 chars)."
  }
}

variable "manage_as_organization" {
  description = "Enable organization-only resources (teams, org actions, runner groups)."
  type        = bool
  default     = false
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

variable "known_repositories" {
  description = "Known repositories in this workspace scope (github-iac-template renamed to github)."
  type        = set(string)
  default = [
    "blacklist",
    "claude",
    "cloudflare",
    "github",
    "hycu_fsds",
    "opencode",
    "opencode-jclee",
    "opencode-slack-notify",
    "propose",
    "proxmox",
    "qqq",
    "resume",
    "safework2",
    "splunk",
    "terraform",
    "tmux",
    "youtube",
  ]
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

variable "organization_secret_selected_repositories" {
  description = "Selected repositories for each organization secret when visibility is selected."
  type        = map(set(string))
  default     = {}
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
      visibility            = "selected"
      selected_repositories = ["terraform"]
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
        wait_timer             = 5
        can_admins_bypass      = true
        prevent_self_review    = true
        protected_branches     = true
        custom_branch_policies = false
      }
      staging = {
        wait_timer             = 0
        can_admins_bypass      = true
        prevent_self_review    = false
        protected_branches     = false
        custom_branch_policies = true
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
    blacklist             = true
    claude                = true
    github                = true
    hycu_fsds             = true
    opencode              = true
    opencode-jclee        = true
    opencode-slack-notify = true
    propose               = true
    qqq                   = true
    resume                = true
    safework2             = true
    splunk                = true
    terraform             = true
    tmux                  = true
    youtube               = true
  }
}

variable "security_code_scanning_tools" {
  description = "Code scanning tools required by ruleset for each repository."
  type        = map(set(string))
  default = {
    blacklist             = ["CodeQL"]
    claude                = ["CodeQL"]
    github                = ["CodeQL"]
    hycu_fsds             = ["CodeQL"]
    opencode              = ["CodeQL"]
    opencode-jclee        = ["CodeQL"]
    opencode-slack-notify = ["CodeQL"]
    propose               = ["CodeQL"]
    qqq                   = ["CodeQL"]
    resume                = ["CodeQL"]
    safework2             = ["CodeQL"]
    splunk                = ["CodeQL"]
    terraform             = ["CodeQL"]
    tmux                  = ["CodeQL"]
    youtube               = ["CodeQL"]
  }
}

variable "enable_repository_rulesets" {
  description = "Enable repository rulesets management."
  type        = bool
  default     = true
}

variable "enable_enterprise_branch_name_pattern" {
  description = "Enable branch_name_pattern rule for enterprise owners only."
  type        = bool
  default     = false
}

variable "enable_repository_imports" {
  description = "Enable import blocks for existing repositories."
  type        = bool
  default     = false
}
