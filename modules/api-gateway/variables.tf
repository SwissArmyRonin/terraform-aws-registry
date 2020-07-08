variable "api_name" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "custom_domain_name" {
  type = string
}

variable "webhook_function_name" {
  type = string
}

variable "registry_function_name" {
  type = string
}

variable "webhook_invoke_arn" {
  type = string
}

variable "registry_invoke_arn" {
  type = string
}

variable "bucket_registry_id" {
  type = string
}

variable "bucket_registry_region" {
  type = string
}
