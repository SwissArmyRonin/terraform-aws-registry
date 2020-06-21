variable "registry_name" {
  description = "The name of the DynamoDB table used to store the registry."
  type        = string
  default     = "terraform-registry"
}

variable "store_bucket" {
  description = "The name of the bucket used to store the module binaries. Either this, or `store_bucket_prefix`, must be set, but not both."
  type        = string
  default     = null
}

variable "store_bucket_prefix" {
  description = "The prefix for the name of the bucket used to store the module binaries. AWS will make a unique name from this. Either this, or `store_bucket`, must be set, but not both."
  type        = string
  default     = null
}

variable "tags" {
  description = "A set of tags that should be applied to all resources, if possible"
  type        = map(string)
}