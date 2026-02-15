variable "elasticsearch_url" {
  description = "Elasticsearch endpoint URL"
  type        = string
  default     = "http://192.168.50.105:9200"
}

variable "elasticsearch_username" {
  description = "Elasticsearch username (empty if xpack security disabled)"
  type        = string
  default     = ""
}

variable "elasticsearch_password" {
  description = "Elasticsearch password (empty if xpack security disabled)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "kibana_url" {
  description = "Kibana endpoint URL"
  type        = string
  default     = "http://192.168.50.105:5601"
}
