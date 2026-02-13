# 220-sandbox: Development Sandbox

**VMID:** 220 | **IP:** 192.168.50.220 | **Status:** Ephemeral
**Specs:** 4GB RAM, 2 cores, 50GB disk (q35/OVMF)

## OVERVIEW
The `220-sandbox` is a dedicated environment for experimental development and transient workloads. It features an automated Cloudflare WARP integration for secure, outbound-only connectivity without exposing the homelab network.

## STRUCTURE
```text
220-sandbox/
├── cloud-init/
│   └── sandbox-user-data.yaml  # Cloud-init definition (WARP, tools)
├── AGENTS.md                   # This file (Operational SoT)
├── BUILD.bazel                # Bazel monorepo target
├── OWNERS                      # Directory ownership
└── README.md                   # User guide
```

## WHERE TO LOOK
| Component | Location | Notes |
|-----------|----------|-------|
| **IaC Definition** | `terraform/main.tf` | Search for `proxmox_virtual_environment_vm.sandbox` |
| **IP / Host SoT** | `terraform/envs/prod/hosts.tf` | Centralized IP management (Source of Truth) |
| **Config Module** | `terraform/modules/vm-config/` | Shared VM configuration patterns |
| **Cloud-Init** | `220-sandbox/cloud-init/` | Automated package/service setup (WARP, tools) |

## CONVENTIONS
- **Ephemeral Lifecycle**: The VM is designed to be destroyed and recreated via Terraform (`terraform destroy/apply -target=...`).
- **Outbound Connectivity**: Cloudflare WARP is used for all external traffic by default.
- **Static IP**: IP `192.168.50.220` is reserved and managed strictly through the IaC Source of Truth.
- **Naming**: Consistent with `{VMID}-{HOSTNAME}` project standard.

## ANTI-PATTERNS
- **NO Manual Configuration**: Do not perform manual setup via SSH that isn't reflected in `cloud-init`.
- **NO Secrets**: Never store production credentials or persistent sensitive data.
- **NO Critical Services**: Do not run any service that requires high availability or backups.
- **NO Persistent Storage**: Assume any data on local disk will be lost during recreation.

## NOTES
- Cloned from template 9000 (Ubuntu).
- WARP mode: Personal (1.1.1.1 DNS + encrypted tunnel).
- Verify WARP status: `warp-cli status` or `curl -s https://www.cloudflare.com/cdn-cgi/trace/ | grep warp`.
- Switch to Zero Trust MDM by writing `/var/lib/cloudflare-warp/mdm.xml` and restarting `warp-svc`.
