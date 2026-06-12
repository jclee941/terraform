terraform {
  required_version = ">= 1.7, < 2.0"

  required_providers {
    elasticstack = {
      source  = "elastic/elasticstack"
      version = ">= 0.13"
    }
  }
}
