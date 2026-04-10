# -----------------------------------------------------------------------------
# 1Password
# -----------------------------------------------------------------------------

variable "onepassword_vault_name" {
  description = "1Password vault name for secret retrieval"
  type        = string
  default     = "homelab"

  validation {
    condition     = length(var.onepassword_vault_name) > 0
    error_message = "vault name must not be empty"
  }
}

# -----------------------------------------------------------------------------
# Synology DSM
# -----------------------------------------------------------------------------

variable "synology_host" {
  description = "Synology DSM HTTPS URL (e.g. https://192.168.50.215:5001)"
  type        = string
  default     = "https://192.168.50.215:5001"

  validation {
    condition     = can(regex("^https://", var.synology_host))
    error_message = "synology_host must start with https://"
  }
}

variable "synology_user" {
  description = "Synology DSM admin username (overridden by 1Password if available)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "synology_password" {
  description = "Synology DSM admin password (overridden by 1Password if available)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "synology_skip_cert_check" {
  description = "Skip TLS certificate verification for self-signed DSM certs"
  type        = bool
  default     = true
}

variable "enable_container_manager_package" {
  description = "Manage ContainerManager package installation via Terraform"
  type        = bool
  default     = false
}

variable "enable_gitlab_project" {
  description = "Enable GitLab CE container project deployment on Synology"
  type        = bool
  default     = false
}

variable "gitlab_version" {
  description = "GitLab CE image tag"
  type        = string
  default     = "17.8.0-ce.0"
}

variable "gitlab_external_url" {
  description = "External URL advertised by GitLab"
  type        = string
  default     = "http://192.168.50.215:8929"
}

variable "gitlab_http_port" {
  description = "Published HTTP port for GitLab web UI"
  type        = string
  default     = "8929"
}

variable "gitlab_ssh_port" {
  description = "Published SSH port for Git over SSH"
  type        = string
  default     = "2224"
}

variable "gitlab_timezone" {
  description = "Timezone used by GitLab container"
  type        = string
  default     = "Asia/Seoul"
}

variable "gitlab_project_share_path" {
  description = "Synology share path for GitLab compose project"
  type        = string
  default     = "/docker/gitlab"
}

# -----------------------------------------------------------------------------
# GitLab Container Registry
# -----------------------------------------------------------------------------

variable "enable_gitlab_registry" {
  description = "Enable GitLab Container Registry"
  type        = bool
  default     = false
}

variable "gitlab_registry_port" {
  description = "Published port for GitLab Container Registry"
  type        = string
  default     = "5050"
}

variable "gitlab_registry_external_url" {
  description = "External URL for GitLab Container Registry"
  type        = string
  default     = "http://192.168.50.215:5050"
}

# -----------------------------------------------------------------------------
# GitLab Runner
# -----------------------------------------------------------------------------

variable "enable_gitlab_runner" {
  description = "Enable GitLab Runner container on Synology"
  type        = bool
  default     = false
}

variable "gitlab_runner_image" {
  description = "GitLab Runner Docker image tag"
  type        = string
  default     = "alpine"
}

variable "gitlab_runner_token" {
  description = "GitLab Runner authentication token (glrt-* prefix, from GitLab UI)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "gitlab_runner_tags" {
  description = "Comma-separated runner tags for job matching"
  type        = string
  default     = "synology,terraform,docker"
}

variable "gitlab_runner_share_path" {
  description = "Synology share path for GitLab Runner compose project"
  type        = string
  default     = "/docker/gitlab-runner"
}
# -----------------------------------------------------------------------------
# Portainer
# -----------------------------------------------------------------------------

variable "enable_portainer" {
  description = "Enable Portainer CE container deployment on Synology"
  type        = bool
  default     = false
}

variable "portainer_version" {
  description = "Portainer CE image tag"
  type        = string
  default     = "latest"
}

variable "portainer_share_path" {
  description = "Synology share path for Portainer compose project"
  type        = string
  default     = "/docker/portainer"
}

variable "portainer_https_port" {
  description = "Published HTTPS port for Portainer web UI"
  type        = string
  default     = "9443"
}

variable "portainer_edge_port" {
  description = "Published TCP port for Portainer Edge agent communication"
  type        = string
  default     = "8000"
}

variable "portainer_timezone" {
  description = "Timezone used by Portainer container"
  type        = string
  default     = "Asia/Seoul"
}
