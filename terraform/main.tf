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

  tags = merge(var.tags, { "Name" = "Terraform Registry" })
}


##############
# S3 storage #
##############

resource "aws_s3_bucket" "registry" {
  bucket        = var.store_bucket
  force_destroy = true
  tags          = merge(var.tags, { "Name" = "Terraform Registry" })
}


##################
# Webhook lambda #
##################

data "aws_iam_policy_document" "lambda" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "webhook_lambda" {
  name                  = var.lambda_webhook_role_name
  assume_role_policy    = data.aws_iam_policy_document.lambda.json
  force_detach_policies = true
  description           = "The role used to execute the webhook lambda"
  tags                  = var.tags
}

resource "aws_iam_role_policy_attachment" "webhook_lambda_basic_execution" {
  role       = aws_iam_role.webhook_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "webhook" {
  type        = "zip"
  source_dir  = format("%s/../lambda/webhook", path.module)
  output_path = format("%s/lib/webhook.zip", path.module)
}

resource "aws_lambda_function" "webhook" {
  filename         = data.archive_file.webhook.output_path
  function_name    = var.lambda_webhook_name
  role             = aws_iam_role.webhook_lambda.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.webhook.output_base64sha256
  runtime          = "nodejs12.x"

  environment {
    variables = {
      "TABLE"         = aws_dynamodb_table.registry.name
      "BUCKET"        = aws_s3_bucket.registry.id
      "GITHUB_SECRET" = var.github_secret
    }
  }

  tags = var.tags
}


###################
# Registry lambda #
###################

data "aws_iam_policy_document" "read_dynamodb" {
  statement {
    actions   = ["dynamodb:GetItem", "dynamodb:Query"]
    resources = [aws_dynamodb_table.registry.arn]
  }
}

data "aws_iam_policy_document" "read_s3" {
  statement {
    actions   = ["s3:Get*", "s3:List*"]
    resources = [format("%s*", aws_s3_bucket.registry.arn)]
  }
}

resource "aws_iam_policy" "read_dynamodb" {
  name   = format("dynamodb-read-%s", var.registry_name)
  policy = data.aws_iam_policy_document.read_dynamodb.json
}

resource "aws_iam_policy" "read_s3" {
  name   = format("s3-read-%s", var.store_bucket)
  policy = data.aws_iam_policy_document.read_s3.json
}

resource "aws_iam_role" "registry_lambda" {
  name                  = var.lambda_registry_role_name
  assume_role_policy    = data.aws_iam_policy_document.lambda.json
  force_detach_policies = true
  description           = "The role used to execute the registry lambda"
  tags                  = var.tags
}

resource "aws_iam_role_policy_attachment" "read_dynamodb" {
  role       = aws_iam_role.registry_lambda.name
  policy_arn = aws_iam_policy.read_dynamodb.arn
}

resource "aws_iam_role_policy_attachment" "read_s3" {
  role       = aws_iam_role.registry_lambda.name
  policy_arn = aws_iam_policy.read_s3.arn
}

resource "aws_iam_role_policy_attachment" "registry_lambda_basic_execution" {
  role       = aws_iam_role.registry_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "registry" {
  type        = "zip"
  source_dir  = format("%s/../lambda/registry", path.module)
  output_path = format("%s/lib/registry.zip", path.module)
}

resource "aws_lambda_function" "registry" {
  filename         = data.archive_file.registry.output_path
  function_name    = var.lambda_registry_name
  role             = aws_iam_role.registry_lambda.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.registry.output_base64sha256
  runtime          = "nodejs12.x"

  environment {
    variables = {
      "TABLE"  = aws_dynamodb_table.registry.name
      "BUCKET" = aws_s3_bucket.registry.id
    }
  }

  tags = var.tags
}


#############
# Discovery #
#############

locals {
  endpoint_root = var.custom_domain_name == null ? format("%s/%s", aws_apigatewayv2_api.registry.api_endpoint, aws_apigatewayv2_stage.registry.name) : format("https://%s", var.custom_domain_name)
}

resource "aws_s3_bucket_object" "discovery_json" {
  bucket        = aws_s3_bucket.registry.id
  acl           = "public-read"
  key           = "terraform.json"
  storage_class = "REDUCED_REDUNDANCY"
  content_type  = "application/json"
  content = jsonencode({
    "modules.v1" = format("%s/modules/", local.endpoint_root)
  })
}


###############
# API gateway #
###############

resource "aws_apigatewayv2_api" "registry" {
  name          = var.api_name
  description   = "Terraform Registry"
  protocol_type = "HTTP"
  tags          = merge(var.tags, { "Name" = "Terraform Registry" })
}

resource "aws_lambda_permission" "webhook_lambda_permission" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.webhook.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = format("%s/live/POST/*", aws_apigatewayv2_api.registry.execution_arn)
}

resource "aws_lambda_permission" "registry_lambda_permission" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.registry.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = format("%s/live/GET/*", aws_apigatewayv2_api.registry.execution_arn)
}

resource "aws_apigatewayv2_integration" "webhook" {
  api_id                 = aws_apigatewayv2_api.registry.id
  integration_type       = "AWS_PROXY"
  description            = "Webhook Lambda to update the Terraform Registry"
  integration_method     = "POST"
  integration_uri        = aws_lambda_function.webhook.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "registry" {
  api_id                 = aws_apigatewayv2_api.registry.id
  integration_type       = "AWS_PROXY"
  description            = "Multi-function Lambda to query the Terraform Registry"
  integration_method     = "POST"
  integration_uri        = aws_lambda_function.registry.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "discovery" {
  api_id             = aws_apigatewayv2_api.registry.id
  integration_type   = "HTTP_PROXY"
  description        = "Proxy the service discovery document in S3"
  integration_method = "GET"
  integration_uri    = format("https://%s.s3.%s.amazonaws.com/%s", aws_s3_bucket.registry.id, aws_s3_bucket.registry.region, aws_s3_bucket_object.discovery_json.key)
}

resource "aws_apigatewayv2_route" "webhook" {
  api_id         = aws_apigatewayv2_api.registry.id
  operation_name = "RegisterRelease"
  route_key      = "POST /webhook"
  target         = format("integrations/%s", aws_apigatewayv2_integration.webhook.id)
}

locals {
  registry_routes = {
    ListModules                                = "GET /modules"
    ListModulesNamespace                       = "GET /modules/{namespace}"
    SearchModules                              = "GET /modules/search"
    ListAvailableVersionsForSpecificModule     = "GET /modules/{namespace}/{name}/{provider}/versions"
    DownloadSourceCodeForSpecificModuleVersion = "GET /modules/{namespace}/{name}/{provider}/{version}/download"
    ListLatestVersionOfModuleForAllProviders   = "GET /modules/{namespace}/{name}"
    LatestVersionForSpecificModuleProvider     = "GET /modules/{namespace}/{name}/{provider}"
    GetSpecificModule                          = "GET /modules/{namespace}/{name}/{provider}/{version}"
    DownloadLatestVersionOfModule              = "GET /modules/{namespace}/{name}/{provider}/download"
  }
}

resource "aws_apigatewayv2_route" "registry_routes" {
  for_each = local.registry_routes

  api_id         = aws_apigatewayv2_api.registry.id
  operation_name = each.key
  route_key      = each.value
  target         = format("integrations/%s", aws_apigatewayv2_integration.registry.id)
}

resource "aws_apigatewayv2_stage" "registry" {
  api_id      = aws_apigatewayv2_api.registry.id
  name        = "live"
  auto_deploy = true
  tags        = var.tags
}

resource "aws_apigatewayv2_route" "discovery" {
  api_id         = aws_apigatewayv2_api.registry.id
  operation_name = "Discovery"
  route_key      = "GET /.wellknown/terraform.json"
  target         = format("integrations/%s", aws_apigatewayv2_integration.discovery.id)
}

