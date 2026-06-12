output "name" {
  description = "Managed index template name."
  value       = elasticstack_elasticsearch_index_template.this.name
}

output "index_patterns" {
  description = "Managed index template patterns."
  value       = elasticstack_elasticsearch_index_template.this.index_patterns
}

output "priority" {
  description = "Managed index template priority."
  value       = elasticstack_elasticsearch_index_template.this.priority
}
