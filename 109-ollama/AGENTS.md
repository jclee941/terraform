# AGENTS: 109-ollama

## OVERVIEW

Ollama local LLM inference server with NVIDIA RTX 5070 Ti GPU passthrough. Provides OpenAI-compatible API for local model serving, used by Archon (108) as LLM backend.

- **VMID**: 109
- **IP**: 192.168.50.109
- **Type**: QEMU VM (GPU passthrough)
- **GPU**: NVIDIA RTX 5070 Ti (PCI 01:00.0, VFIO)
- **Domain**: ollama.jclee.me (via Traefik)

## STRUCTURE

```
109-ollama/
├── BUILD.bazel              # Bazel governance
├── OWNERS                   # Ownership
├── AGENTS.md                # This file
├── ollama-user-data.yaml    # Cloud-init (uploaded to pve:/var/lib/vz/snippets/)
└── terraform/               # Standalone TF workspace (main.tf, variables.tf)
```

## WHERE TO LOOK

| Task                   | Location                                                 |
| ---------------------- | -------------------------------------------------------- |
| Service ports/IP       | `100-pve/envs/prod/hosts.tf` (ollama entry)              |
| VM provisioning        | `100-pve/main.tf` (vm_definitions → ollama)              |
| GPU passthrough config | `100-pve/main.tf` (hostpci_devices)                      |
| Cloud-init             | `ollama-user-data.yaml` (NVIDIA driver + Ollama install) |
| VM module              | `modules/proxmox/vm/` (hostpci dynamic block)            |

## PORTS

| Port  | Service                        |
| ----- | ------------------------------ |
| 11434 | Ollama API (OpenAI-compatible) |

## CONVENTIONS

- App-config workspace; VM lifecycle owned by 100-pve/main.tf
- Uses `terraform_remote_state.infra` for host IP/VMID resolution from 100-pve
- GPU passthrough via VFIO-PCI (host pre-configured, IOMMU enabled)
- Cloud-init installs NVIDIA drivers + Ollama on first boot
- Ollama listens on 0.0.0.0:11434 (all interfaces)

## ANTI-PATTERNS

- **NO** manual GPU driver installation — use cloud-init
- **NO** hardcoded IPs — use module.hosts from hosts.tf
- **NO** UI changes to VM resources (managed by Terraform)
- **NO** disabling VFIO-PCI on PVE host — GPU is dedicated to this VM

## DEPENDENCIES

- **Upstream**: PVE host (VFIO-PCI, IOMMU), clone template 9000
- **Downstream**: 108-archon (Ollama as LLM provider)
