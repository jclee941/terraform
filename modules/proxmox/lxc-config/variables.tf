variable "lxc_containers" {
  description = "Map of LXC container configurations"
  type = map(object({
    vmid       = number
    hostname   = string
    ip_address = string

    systemd_services = optional(map(object({
      description          = string
      exec_start           = string
      working_dir          = optional(string)
      user                 = optional(string, "root")
      restart              = optional(string, "always")
      restart_sec          = optional(number, 5)
      env_file             = optional(string)
      env_vars             = optional(map(string), {})
      after                = optional(string, "network.target")
      wanted_by            = optional(string, "multi-user.target")
      start_limit_burst    = optional(number, 5)
      start_limit_interval = optional(number, 300)
    })), {})

    config_files = optional(map(object({
      path        = string
      content     = string
      permissions = optional(string, "0644")
    })), {})

    docker_compose = optional(object({
      path    = string
      content = string
    }))

    cloud_init = optional(object({
      packages = optional(list(string), [])
      write_files = optional(list(object({
        path        = string
        content     = string
        permissions = optional(string, "0644")
        owner       = optional(string, "root:root")
      })), [])
      runcmd = optional(list(string), [])
    }), {})

    deploy         = optional(bool, false)
    setup_filebeat = optional(bool, false)
  }))

  default = {}
}


variable "deploy_lxc_configs" {
  description = "Whether to deploy LXC configurations via SSH"
  type        = bool
  default     = false
}

variable "enable_health_checks" {
  description = "Verify services are running after deployment with systemctl is-active"
  type        = bool
  default     = false
}

variable "health_check_delay" {
  description = "Seconds to wait before health check (allows service startup)"
  type        = number
  default     = 3
}

variable "ssh_private_key" {
  description = "SSH private key content for LXC remote provisioners"
  type        = string
  sensitive   = true
  default     = ""
}

variable "ssh_user" {
  description = "SSH user for LXC remote provisioners"
  type        = string
  default     = "root"
}
