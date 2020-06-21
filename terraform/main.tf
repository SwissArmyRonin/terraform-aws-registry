#####################
# DynamoDB registry #
#####################

resource "aws_dynamodb_table" "registry" {
  name = var.registry_name

  hash_key  = "Id"
  range_key = "Version"

  billing_mode = "PAY_PER_REQUEST"

  # Id is the full namespace/name/provider string used to identify a particular module.
  attribute {
    name = "Id"
    type = "S"
  }

  # Version is a normalized semver-style version number, like 1.0.0.
  attribute {
    name = "Version"
    type = "S"
  }

  # attribute {
  #   name = "ModuleArn"
  #   type = "S"
  # }

  # attribute {
  #   name = "VersionMd5"
  #   type = "S"
  # }

  tags = merge(var.tags, { "Name" = "Terraform Registry" })
}

##############
# S3 storage #
##############

resource "aws_s3_bucket" "registry" {
  bucket        = var.store_bucket
  bucket_prefix = var.store_bucket == null ? var.store_bucket : null # An explicit bucket name takes precedence
  tags          = merge(var.tags, { "Name" = "Terraform Registry" })
}




################
# Clone lambda #
################

###################
# Registry lambda #
###################

###############
# API gateway #
###############