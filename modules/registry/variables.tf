variable "assume_role_policy" {
  type = string
}

variable "dynamodb_registry_arn" {
  type = string
}

variable "bucket_registry_arn" {
  type = string
}

variable "role_name" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "registry_name" {
  type = string
}

variable "store_bucket" {
  type = string
}

variable "function_name" {
  type = string
}