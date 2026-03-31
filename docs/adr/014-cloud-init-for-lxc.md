# ADR 014: Cloud-Init for LXC Containers

**Status**: Proposed
**Date**: 2026-03-28
**Author**: Sisyphus (AI Agent)
**Scope**: 100-pve, modules/proxmox/lxc-config

## Context

Currently, cloud-init is only used for VMs via the `vm-config` module. LXC containers use systemd service templates for configuration management. This creates inconsistency in the infrastructure provisioning approach and misses out on cloud-init's declarative configuration benefits for LXC containers.

The user requested "cloud init 전체 적용" (apply cloud-init to all), which requires extending cloud-init support to LXC containers.

## Decision

We will implement **Option A: SSH-based cloud-init simulation** for LXC containers.

### Rationale

| Criteria | Option A (SSH-based) | Option B (cloud-init package) | Option C (systemd-first-boot) |
|----------|----------------------|------------------------------|------------------------------|
| **Complexity** | Medium - Requires SSH + template rendering | Medium - Requires cloud-init package in LXC | Low - Uses existing systemd |
| **Consistency** | High - Same interface as VMs | High - Native cloud-init | Low - Different pattern |
| **Idempotency** | High - Sentinel files track execution | High - cloud-init handles this | Medium - Custom logic needed |
| **Rollback** | Easy - Remove sentinel, re-run | Medium - cloud-init clean required | Hard - Manual cleanup |
| **Performance** | Fast - Direct SSH | Slow - cloud-init overhead | Fast - Native systemd |
| **Risk** | Low - Proven pattern | Medium - cloud-init in LXC less tested | Low - Already used |

**Decision**: Option A provides the best balance of consistency with VM provisioning, idempotency, and low risk. It leverages the existing SSH infrastructure already in place for LXC config deployment.

## Implementation Approach

### 1. Extend lxc-config Module

Add `cloud_init` block to the LXC configuration interface:

```hcl
variable "containers" {
  type = map(object({
    # ... existing fields ...
    cloud_init = optional(object({
      packages    = optional(list(string), [])
      runcmd      = optional(list(string), [])
      write_files = optional(list(object({
        path        = string
        content     = string
        permissions = optional(string, "0644")
        owner       = optional(string, "root:root")
      })), [])
    }), {})
  }))
}
```

### 2. Create LXC Cloud-Init Template

New template: `modules/proxmox/lxc-config/templates/cloud-init-lxc.yaml.tftpl`

Same structure as VM cloud-init but optimized for LXC:
- No `growpart` (LXC doesn't need disk resizing)
- No network config (managed by Proxmox)
- Focus on packages, write_files, runcmd

### 3. Deployment Mechanism

Use existing SSH infrastructure in `lxc-config/main.tf`:

```hcl
resource "null_resource" "cloud_init_deploy" {
  for_each = var.deploy_lxc_configs ? var.containers : {}

  triggers = {
    cloud_init_hash = md5(templatefile("${path.module}/templates/cloud-init-lxc.yaml.tftpl", {
      hostname    = each.value.hostname
      packages    = each.value.cloud_init.packages
      runcmd      = each.value.cloud_init.runcmd
      write_files = each.value.cloud_init.write_files
    }))
  }

  connection {
    type        = "ssh"
    host        = each.value.ip
    user        = var.ssh_user
    private_key = var.ssh_private_key
  }

  # Upload cloud-init config
  provisioner "file" {
    content     = templatefile("${path.module}/templates/cloud-init-lxc.yaml.tftpl", {...})
    destination = "/etc/cloud/cloud.cfg.d/99-terraform.cfg"
  }

  # Execute cloud-init (or simulate it)
  provisioner "remote-exec" {
    inline = [
      # Check if already executed
      "[ -f /var/lib/cloud/.terraform-init-done ] \u0026\u0026 exit 0",
      # Install packages
      "apt-get update",
      "apt-get install -y ${join(" ", each.value.cloud_init.packages)}",
      # Write files
      # ... file writing logic ...
      # Run commands
      "${join("\n", each.value.cloud_init.runcmd)}",
      # Mark as done
      "touch /var/lib/cloud/.terraform-init-done",
    ]
  }
}
```

### 4. Idempotency Strategy

- Use sentinel file: `/var/lib/cloud/.terraform-init-done`
- Store hash of cloud-init config in sentinel
- Re-run if config changes (hash mismatch)
- Re-run if sentinel missing

### 5. Migration Path

1. Add cloud_init blocks to all LXC containers in `100-pve/lxc_configs.tf`
2. Migrate existing `config_files` and `systemd_services` to cloud_init where appropriate
3. Keep both systems running during transition
4. Remove old system after validation

## Consequences

### Positive
- Consistent configuration interface across VMs and LXCs
- Declarative configuration (packages, files, commands)
- Idempotent deployments
- Easier to reason about container state

### Negative
- Additional complexity in lxc-config module
- SSH dependency for all LXC initial configuration
- Potential for drift if cloud-init is manually modified

### Risks
- SSH connectivity issues could block deployments
- Cloud-init execution failures may leave containers in partial state
- Migration complexity for existing containers

## Mitigations

1. **SSH Failure**: Fall back to manual execution documented in runbook
2. **Partial State**: Clear sentinel file to force re-run
3. **Migration**: Phase rollout - test with 1-2 containers first

## Related Decisions

- ADR 012: LXC vs VM provisioning strategy
- ADR 010: SSH-based configuration deployment

## References

- [Cloud-init documentation](https://cloudinit.readthedocs.io/)
- [Proxmox LXC documentation](https://pve.proxmox.com/wiki/Linux_Container)
- modules/proxmox/vm-config/templates/cloud-init.yaml.tftpl

## Status History

- 2026-03-28: Proposed
