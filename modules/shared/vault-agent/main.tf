terraform {
  required_version = ">= 1.7, < 2.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

resource "vault_auth_backend" "approle" {
  count = var.create_approle_backend ? 1 : 0
  type  = "approle"
  path  = "approle"
}

resource "vault_policy" "service" {
  name = "${var.service_name}-agent"

  policy = join("\n", concat(
    [
      "path \"${var.vault_mount}/data/${var.kv_path}\" {",
      "  capabilities = [\"read\"]",
      "}",
      "path \"${var.vault_mount}/metadata/${var.kv_path}\" {",
      "  capabilities = [\"read\"]",
      "}",
    ],
    flatten([for p in var.additional_kv_paths : [
      "path \"${var.vault_mount}/data/${p}\" {",
      "  capabilities = [\"read\"]",
      "}",
      "path \"${var.vault_mount}/metadata/${p}\" {",
      "  capabilities = [\"read\"]",
      "}",
    ]])
  ))
}

resource "vault_approle_auth_backend_role" "service" {
  backend   = var.approle_backend_path
  role_name = "${var.service_name}-agent"

  token_policies = [
    vault_policy.service.name,
  ]

  token_ttl     = var.token_ttl
  token_max_ttl = var.token_max_ttl
}

# TODO(vault-v5): Convert to ephemeral resource when upgrading to vault provider v5.x + TF >= 1.11
resource "vault_approle_auth_backend_role_secret_id" "service" {
  backend   = var.approle_backend_path
  role_name = vault_approle_auth_backend_role.service.role_name
}

locals {
  vault_agent_config = templatefile("${path.module}/templates/vault-agent.hcl.tftpl", {
    vault_addr        = var.vault_addr
    role_id           = vault_approle_auth_backend_role.service.role_id
    backend_path      = var.approle_backend_path
    vault_mount       = var.vault_mount
    kv_path           = var.kv_path
    template_mappings = var.template_mappings
  })

  vault_agent_service = templatefile("${path.module}/templates/vault-agent.service.tftpl", {
    service_name = var.service_name
    config_path  = "/etc/vault-agent/${var.service_name}.hcl"
  })
}
