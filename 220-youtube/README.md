# 220-youtube: YouTube Media Server VM

A dedicated virtual machine for YouTube media workloads.

## Quick Start

```bash
# SSH access
ssh youtube
ssh jclee@192.168.50.220
```

## Specifications

| Component | Value                 |
| --------- | --------------------- |
| **VMID**  | 220                   |
| **IP**    | 192.168.50.220        |
| **Type**  | VM (QEMU/KVM)         |
| **CPU**   | 2 cores               |
| **RAM**   | 4 GB                  |
| **Disk**  | 50 GB                 |
| **OS**    | Linux (Ubuntu/Debian) |

## Purpose

- YouTube media processing
- Media content management
- Streaming workloads

## Guidelines

1. **Ephemeral**: This VM can be destroyed and recreated anytime
2. **No Secrets**: Don't store production credentials
3. **Self-Service**: Free to modify and experiment
4. **Not Backed Up**: Transient by design

## Terraform Management

```bash
# Recreate youtube VM
cd 100-pve
terraform destroy -target=module.vm["youtube"]
terraform apply -target=module.vm["youtube"]
```

## See Also

- [AGENTS.md](./AGENTS.md) - Technical specifications
- [100-pve](../100-pve/) - IaC definitions
