# 220-sandbox: Development/Test Sandbox VM

A general-purpose sandbox virtual machine for development testing, experiments, and temporary workloads.

## Quick Start

```bash
# SSH access
ssh sandbox
ssh jclee@192.168.50.220
```

## Specifications

| Component | Value |
|-----------|-------|
| **VMID** | 220 |
| **IP** | 192.168.50.220 |
| **Type** | VM (QEMU/KVM) |
| **CPU** | 2 cores |
| **RAM** | 4 GB |
| **Disk** | 50 GB |
| **OS** | Linux (Ubuntu/Debian) |

## Purpose

- Development testing
- Configuration experiments
- Temporary workloads
- Learning new technologies

## Guidelines

1. **Ephemeral**: This VM can be destroyed and recreated anytime
2. **No Secrets**: Don't store production credentials
3. **Self-Service**: Free to modify and experiment
4. **Not Backed Up**: Transient by design

## Terraform Management

```bash
# Recreate sandbox
cd terraform/proxmox-tf
terraform destroy -target=proxmox_virtual_environment_vm.sandbox
terraform apply -target=proxmox_virtual_environment_vm.sandbox
```

## See Also

- [AGENTS.md](./AGENTS.md) - Technical specifications
- [terraform](../terraform/) - IaC definitions
