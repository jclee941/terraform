# Workers Scripts
resource "cloudflare_workers_script" "scripts" {
  for_each = var.workers

  account_id = var.cloudflare_account_id
  name       = each.value.script_name
  content    = file(each.value.content_file)

  dynamic "plain_text_binding" {
    for_each = [
      for binding in each.value.bindings :
      binding if binding.type == "plain_text"
    ]
    content {
      name = plain_text_binding.value.name
      text = plain_text_binding.value.text
    }
  }

  dynamic "secret_text_binding" {
    for_each = [
      for binding in each.value.bindings :
      binding if binding.type == "secret_text"
    ]
    content {
      name = secret_text_binding.value.name
      text = secret_text_binding.value.text
    }
  }

  dynamic "r2_bucket_binding" {
    for_each = [
      for binding in each.value.bindings :
      binding if binding.type == "r2_bucket"
    ]
    content {
      name        = r2_bucket_binding.value.name
      bucket_name = r2_bucket_binding.value.bucket_name
    }
  }

  dynamic "kv_namespace_binding" {
    for_each = [
      for binding in each.value.bindings :
      binding if binding.type == "kv_namespace"
    ]
    content {
      name         = kv_namespace_binding.value.name
      namespace_id = kv_namespace_binding.value.namespace_id
    }
  }

  dynamic "d1_database_binding" {
    for_each = [
      for binding in each.value.bindings :
      binding if binding.type == "d1"
    ]
    content {
      name        = d1_database_binding.value.name
      database_id = d1_database_binding.value.database_id
    }
  }
}

# Workers Routes
resource "cloudflare_workers_route" "routes" {
  for_each = var.worker_routes

  zone_id     = var.cloudflare_zone_id
  pattern     = each.value.pattern
  script_name = each.value.script_name

  depends_on = [cloudflare_workers_script.scripts]
}
