variable "name" {
  description = "Elasticsearch ILM policy name."
  type        = string
}

variable "min_age" {
  description = "Minimum age before the delete phase runs."
  type        = string
}

variable "priority" {
  description = "Hot phase index priority."
  type        = number
  default     = 100
}

variable "warm_min_age" {
  description = "Minimum index age before force-merging to one segment; null disables the warm phase."
  type        = string
  default     = null
}
