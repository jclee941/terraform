variable "vms" {
  description = "Map of VM configurations"
  type = map(object({
    vmid        = number
    hostname    = string
    ip_address  = string
    gateway     = optional(string)
    dns_servers = optional(list(string))

    cloud_init = optional(object({
      packages = optional(list(string), ["qemu-guest-agent", "curl", "vim"])
      runcmd   = optional(list(string), [])
      write_files = optional(list(object({
        path        = string
        content     = string
        permissions = optional(string, "0644")
        owner       = optional(string, "root:root")
      })), [])
    }), {})

    systemd_services = optional(map(object({
      description = string
      exec_start  = string
      working_dir = optional(string)
      user        = optional(string, "root")
      restart     = optional(string, "always")
      env_vars    = optional(map(string), {})
      after       = optional(string, "network.target")
      wanted_by   = optional(string, "multi-user.target")
    })), {})

    setup_filebeat = optional(bool, false)
    deploy         = optional(bool, false)
  }))

  default = {

    sandbox = {
      vmid       = 220
      hostname   = "sandbox"
      ip_address = "192.168.50.220"

      cloud_init = {
        packages = ["qemu-guest-agent", "curl", "vim", "git"]
        runcmd   = ["systemctl enable qemu-guest-agent", "systemctl start qemu-guest-agent"]
      }
    }
  }
}

variable "deploy_vm_configs" {
  description = "Whether to deploy VM configurations via SSH"
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

variable "ssh_user" {
  description = "SSH user for VM connections"
  type        = string
  default     = "root"
}

variable "ssh_private_key" {
  description = "SSH private key content for VM remote provisioners"
  type        = string
  sensitive   = true
  default     = ""
}
