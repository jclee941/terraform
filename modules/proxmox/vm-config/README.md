# Proxmox VM Config Module

Renders and deploys configuration files to QEMU VMs via SSH.
Supports cloud-init templates and post-provisioning config deployment
using the hosts map pattern from `envs/prod/hosts.tf`.

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
| [local_file.cloud_init](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.systemd_services](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [null_resource.deploy_systemd_services](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.deploy_vm_write_files](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.health_check_systemd](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.install_filebeat](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_deploy_vm_configs"></a> [deploy\_vm\_configs](#input\_deploy\_vm\_configs) | Whether to deploy VM configurations via SSH | `bool` | `false` | no |
| <a name="input_enable_health_checks"></a> [enable\_health\_checks](#input\_enable\_health\_checks) | Verify services are running after deployment with systemctl is-active | `bool` | `false` | no |
| <a name="input_health_check_delay"></a> [health\_check\_delay](#input\_health\_check\_delay) | Seconds to wait before health check (allows service startup) | `number` | `3` | no |
| <a name="input_ssh_private_key"></a> [ssh\_private\_key](#input\_ssh\_private\_key) | SSH private key content for VM remote provisioners | `string` | `""` | no |
| <a name="input_ssh_user"></a> [ssh\_user](#input\_ssh\_user) | SSH user for VM connections | `string` | `"root"` | no |
| <a name="input_vms"></a> [vms](#input\_vms) | Map of VM configurations | <pre>map(object({<br/>    vmid        = number<br/>    hostname    = string<br/>    ip_address  = string<br/>    gateway     = optional(string)<br/>    dns_servers = optional(list(string))<br/><br/>    cloud_init = optional(object({<br/>      packages = optional(list(string), ["qemu-guest-agent", "curl", "vim"])<br/>      runcmd   = optional(list(string), [])<br/>      write_files = optional(list(object({<br/>        path        = string<br/>        content     = string<br/>        permissions = optional(string, "0644")<br/>        owner       = optional(string, "root:root")<br/>        encoding    = optional(string, "")<br/>      })), [])<br/>    }), {})<br/><br/>    systemd_services = optional(map(object({<br/>      description = string<br/>      exec_start  = string<br/>      working_dir = optional(string)<br/>      user        = optional(string, "root")<br/>      restart     = optional(string, "always")<br/>      env_vars    = optional(map(string), {})<br/>      after       = optional(string, "network.target")<br/>      wanted_by   = optional(string, "multi-user.target")<br/>    })), {})<br/><br/>    setup_filebeat = optional(bool, false)<br/>    deploy         = optional(bool, false)<br/>  }))</pre> | <pre>{<br/>  "sandbox": {<br/>    "cloud_init": {<br/>      "packages": [<br/>        "qemu-guest-agent",<br/>        "curl",<br/>        "vim",<br/>        "git"<br/>      ],<br/>      "runcmd": [<br/>        "systemctl enable qemu-guest-agent",<br/>        "systemctl start qemu-guest-agent"<br/>      ]<br/>    },<br/>    "hostname": "sandbox",<br/>    "ip_address": "192.168.50.220",<br/>    "vmid": 220<br/>  }<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloud_init_paths"></a> [cloud\_init\_paths](#output\_cloud\_init\_paths) | Map of VM name to cloud-init file path |
| <a name="output_vm_configs"></a> [vm\_configs](#output\_vm\_configs) | Generated VM configuration paths |
<!-- END_TF_DOCS -->
