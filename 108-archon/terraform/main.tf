# Archon app-config workspace (reserved for future Archon provider integration).
# LXC lifecycle is managed by 100-pve/main.tf. Config deployment uses
# config-renderer pipeline (templates/ → tf-configs/).
#
# Future provider resources:
#   - Archon knowledge base management
#   - MCP server configuration
#   - Agent workflow definitions

locals {
  hosts = try(data.terraform_remote_state.infra.outputs.host_inventory, {})
}
