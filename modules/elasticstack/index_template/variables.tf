variable "name" {
  description = "Elasticsearch index template name."
  type        = string
}

variable "index_patterns" {
  description = "Index patterns matched by this template."
  type        = list(string)
}

variable "lifecycle_policy_name" {
  description = "ILM policy name assigned through index.lifecycle.name."
  type        = string
}

variable "number_of_replicas" {
  description = "Index number_of_replicas setting."
  type        = number
  default     = 0
}

variable "number_of_shards" {
  description = "Index number_of_shards setting."
  type        = number
  default     = 1
}

variable "priority" {
  description = "Index template priority."
  type        = number
}

variable "index_codec" {
  description = "Codec used to compress stored index data."
  type        = string
  default     = null
}

variable "refresh_interval" {
  description = "Interval between automatic index refreshes."
  type        = string
  default     = null
}
