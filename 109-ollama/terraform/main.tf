# Ollama app-config workspace (reserved for future Ollama-specific resources).
# VM lifecycle is managed by 100-pve/main.tf with GPU passthrough (RTX 5070 Ti).
# Cloud-init handles NVIDIA driver + Ollama installation.

locals {
  hosts = try(data.terraform_remote_state.infra.outputs.host_inventory, {})
}
