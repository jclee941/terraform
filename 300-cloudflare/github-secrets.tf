resource "github_actions_secret" "managed" {
  for_each = nonsensitive(var.github_token) != "" ? local.github_secrets : {}

  repository      = each.value.repository
  secret_name     = each.value.secret_name
  plaintext_value = var.secret_values[each.value.secret_name]

  lifecycle {
    precondition {
      condition     = contains(keys(var.secret_values), each.value.secret_name)
      error_message = "Missing var.secret_values entry for ${each.value.secret_name}."
    }
  }
}
