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


################
# Clone lambda #
################

# TODO


###################
# Registry lambda #
###################

data "aws_iam_policy_document" "registry_lambda" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

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
  assume_role_policy    = data.aws_iam_policy_document.registry_lambda.json
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

resource "aws_iam_role_policy_attachment" "registry_lambda_basic_excution" {
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

  tags = merge(var.tags, { "Name" = "Terraform Registry" })
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

resource "aws_lambda_permission" "lambda_permission" {
  statement_id  = "AllowMyDemoAPIInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.registry.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = format("%s/*/*/*", aws_apigatewayv2_api.registry.execution_arn)
}

resource "aws_apigatewayv2_integration" "registry" {
  api_id                 = aws_apigatewayv2_api.registry.id
  integration_type       = "AWS_PROXY"
  description            = "Multi-function Lambda to query the Terraform Registry"
  integration_method     = "POST"
  integration_uri        = aws_lambda_function.registry.invoke_arn
  passthrough_behavior   = "WHEN_NO_MATCH" # Marked as changed every time (TF bug?)
  payload_format_version = "2.0"
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
