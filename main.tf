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

  tags = merge(var.tags, { "Name" = "Terraform Registry" })
}


resource "aws_s3_bucket" "registry" {
  bucket        = var.store_bucket
  force_destroy = true
  tags          = merge(var.tags, { "Name" = "Terraform Registry" })
}


data "aws_iam_policy_document" "lambda" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}


module "webhook" {
  source                = "./modules/webhook"
  function_name         = var.lambda_webhook_name
  assume_role_policy    = data.aws_iam_policy_document.lambda.json
  dynamodb_registry_arn = aws_dynamodb_table.registry.arn
  registry_name         = aws_dynamodb_table.registry.name
  bucket_registry_arn   = aws_s3_bucket.registry.arn
  store_bucket          = aws_s3_bucket.registry.id
  role_name             = var.lambda_webhook_role_name
  ssm_prefix            = var.ssm_prefix
  github_secret         = var.github_secret
  access_tokens         = var.access_tokens
  tags                  = var.tags
}


module "registry" {
  source                = "./modules/registry"
  function_name         = var.lambda_registry_name
  assume_role_policy    = data.aws_iam_policy_document.lambda.json
  dynamodb_registry_arn = aws_dynamodb_table.registry.arn
  registry_name         = aws_dynamodb_table.registry.name
  bucket_registry_arn   = aws_s3_bucket.registry.arn
  store_bucket          = aws_s3_bucket.registry.id
  role_name             = var.lambda_registry_role_name
  tags                  = var.tags
}



module "api-gateway" {
  source                 = "./modules/api-gateway"
  api_name               = var.api_name
  tags                   = var.tags
  custom_domain_name     = var.custom_domain_name
  webhook_function_name  = module.webhook.function_name
  webhook_invoke_arn     = module.webhook.invoke_arn
  registry_function_name = module.registry.function_name
  registry_invoke_arn    = module.registry.invoke_arn
  bucket_registry_id     = aws_s3_bucket.registry.id
  bucket_registry_region = aws_s3_bucket.registry.region
}
