variable "registry_name" {
  description = "The name of the DynamoDB table used to store the registry."
  type        = string
  default     = "terraform-registry"
}

variable "store_bucket" {
  description = "The name of the bucket used to store the module binaries."
  type        = string
}

variable "lambda_webhook_name" {
  description = "The name of the lambda that handles Terraform registry update."
  type        = string
  default     = "terraform-webhook"
}

variable "lambda_registry_name" {
  description = "The name of the lambda that handles Terraform registry queries."
  type        = string
  default     = "terraform-registry"
}

variable "lambda_webhook_role_name" {
  description = "The name of the role used to execute the webhook lambda."
  type        = string
  default     = "terraform-webhook-role"
}

variable "lambda_registry_role_name" {
  description = "The name of the role used to execute the registry lambda."
  type        = string
  default     = "terraform-registry-role"
}

variable "api_name" {
  description = "The name of the API gateway that fronts the registry."
  type        = string
  default     = "terraform-registry"
}

variable "github_secret" {
  description = "The secret used by GitHub webhooks"
  type        = string
}

variable "tags" {
  description = "A set of tags that should be applied to all resources, if possible"
  type        = map(string)
}

variable "custom_domain_name" {
  description = "If a custom domain name is assigned to the API gateway, provide it here"
  type        = string
  default     = null
}