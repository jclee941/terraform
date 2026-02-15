resource "vault_kv_secret_v2" "managed" {
  for_each = nonsensitive(var.vault_token != "" && length(var.secret_values) > 0) ? local.vault_secrets : {}

  mount = var.vault_mount_path
  name  = each.key

  data_json = jsonencode({
    for secret_name in each.value :
    secret_name => var.secret_values[secret_name]
  })

  lifecycle {
    precondition {
      condition = alltrue([
        for secret_name in each.value : contains(keys(var.secret_values), secret_name)
      ])
      error_message = "Missing one or more var.secret_values entries for Vault path ${each.key}."
    }
  }
}
