output "name" {
  description = "Managed ILM policy name."
  value       = elasticstack_elasticsearch_index_lifecycle.this.name
}
