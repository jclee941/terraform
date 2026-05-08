# Proxmox LXC Config Module

Renders and deploys configuration files to LXC containers via SSH.
Uses `templatefile()` with the hosts map pattern for dynamic config
generation (systemd units, docker-compose, app configs).

## Architecture

```mermaid
flowchart LR
  Inputs["Input variables"] --> Module["Terraform module"]
  Module --> Resources["Managed resources or rendered templates"]
  Resources --> Outputs["Output values"]
  Outputs --> Consumers["Workspace consumers"]
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7, < 2.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | ~> 2.5 |
| <a name="requirement_null"></a> [null](#requirement\_null) | ~> 3.2 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_local"></a> [local](#provider\_local) | 2.6.2 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.4 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [local_file.cloud_init_configs](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.systemd_services](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_sensitive_file.config_files](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/sensitive_file) | resource |
| [local_sensitive_file.docker_compose](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/sensitive_file) | resource |
| [null_resource.deploy_cloud_init](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.deploy_config_files](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.deploy_systemd_services](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.health_check_systemd](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.install_filebeat](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_deploy_lxc_configs"></a> [deploy\_lxc\_configs](#input\_deploy\_lxc\_configs) | Whether to deploy LXC configurations via SSH | `bool` | `false` | no |
| <a name="input_enable_health_checks"></a> [enable\_health\_checks](#input\_enable\_health\_checks) | Verify services are running after deployment with systemctl is-active | `bool` | `false` | no |
| <a name="input_health_check_delay"></a> [health\_check\_delay](#input\_health\_check\_delay) | Seconds to wait before health check (allows service startup) | `number` | `3` | no |
| <a name="input_lxc_containers"></a> [lxc\_containers](#input\_lxc\_containers) | Map of LXC container configurations | <pre>map(object({<br/>    vmid       = number<br/>    hostname   = string<br/>    ip_address = string<br/><br/>    systemd_services = optional(map(object({<br/>      description          = string<br/>      exec_start           = string<br/>      working_dir          = optional(string)<br/>      user                 = optional(string, "root")<br/>      restart              = optional(string, "always")<br/>      restart_sec          = optional(number, 5)<br/>      env_file             = optional(string)<br/>      env_vars             = optional(map(string), {})<br/>      after                = optional(string, "network.target")<br/>      wanted_by            = optional(string, "multi-user.target")<br/>      start_limit_burst    = optional(number, 5)<br/>      start_limit_interval = optional(number, 300)<br/>    })), {})<br/><br/>    config_files = optional(map(object({<br/>      path        = string<br/>      content     = string<br/>      permissions = optional(string, "0644")<br/>    })), {})<br/><br/>    docker_compose = optional(object({<br/>      path    = string<br/>      content = string<br/>    }))<br/><br/>    cloud_init = optional(object({<br/>      packages = optional(list(string), [])<br/>      write_files = optional(list(object({<br/>        path        = string<br/>        content     = string<br/>        permissions = optional(string, "0644")<br/>        owner       = optional(string, "root:root")<br/>      })), [])<br/>      runcmd = optional(list(string), [])<br/>    }), {})<br/><br/>    deploy         = optional(bool, false)<br/>    setup_filebeat = optional(bool, false)<br/>  }))</pre> | `{}` | no |
| <a name="input_mcp_host"></a> [mcp\_host](#input\_mcp\_host) | MCP server host IP (MCPHub VM 112) | `string` | n/a | yes |
| <a name="input_ssh_private_key"></a> [ssh\_private\_key](#input\_ssh\_private\_key) | SSH private key content for LXC remote provisioners | `string` | `""` | no |
| <a name="input_ssh_user"></a> [ssh\_user](#input\_ssh\_user) | SSH user for LXC remote provisioners | `string` | `"root"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_lxc_configs"></a> [lxc\_configs](#output\_lxc\_configs) | Generated LXC configuration paths |
| <a name="output_service_count"></a> [service\_count](#output\_service\_count) | Total number of systemd services managed |
<!-- END_TF_DOCS -->
