locals {
  endpoint_root = var.custom_domain_name == null ? format("%s/%s", aws_apigatewayv2_api.registry.api_endpoint, aws_apigatewayv2_stage.registry.name) : format("https://%s", var.custom_domain_name)
}

resource "aws_apigatewayv2_api" "registry" {
  name          = var.api_name
  description   = "Terraform Registry"
  protocol_type = "HTTP"
  tags          = merge(var.tags, { "Name" = "Terraform Registry" })
}

resource "aws_apigatewayv2_stage" "registry" {
  api_id      = aws_apigatewayv2_api.registry.id
  name        = "live"
  auto_deploy = true
  tags        = var.tags
}



################################################################################
# Discovery
################################################################################

resource "aws_s3_bucket_object" "discovery_json" {
  bucket        = var.bucket_registry_id
  acl           = "public-read"
  key           = "terraform.json"
  storage_class = "REDUCED_REDUNDANCY"
  content_type  = "application/json"
  content = jsonencode({
    "modules.v1" = format("%s/modules/", local.endpoint_root)
  })
}

resource "aws_apigatewayv2_route" "discovery" {
  api_id         = aws_apigatewayv2_api.registry.id
  operation_name = "Discovery"
  route_key      = "GET /.wellknown/terraform.json"
  target         = format("integrations/%s", aws_apigatewayv2_integration.discovery.id)
}



################################################################################
# Webhook
################################################################################

resource "aws_lambda_permission" "webhook_lambda_permission" {
  action        = "lambda:InvokeFunction"
  function_name = var.webhook_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = format("%s/live/POST/*", aws_apigatewayv2_api.registry.execution_arn)
}

resource "aws_apigatewayv2_integration" "webhook" {
  api_id                 = aws_apigatewayv2_api.registry.id
  integration_type       = "AWS_PROXY"
  description            = "Webhook Lambda to update the Terraform Registry"
  integration_method     = "POST"
  integration_uri        = var.webhook_invoke_arn
  payload_format_version = "2.0"
}

resource "aws_lambda_permission" "registry_lambda_permission" {
  action        = "lambda:InvokeFunction"
  function_name = var.registry_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = format("%s/live/GET/*", aws_apigatewayv2_api.registry.execution_arn)
}

resource "aws_apigatewayv2_route" "webhook" {
  api_id         = aws_apigatewayv2_api.registry.id
  operation_name = "RegisterRelease"
  route_key      = "POST /webhook"
  target         = format("integrations/%s", aws_apigatewayv2_integration.webhook.id)
}



################################################################################
# Registry
################################################################################

resource "aws_apigatewayv2_integration" "registry" {
  api_id                 = aws_apigatewayv2_api.registry.id
  integration_type       = "AWS_PROXY"
  description            = "Multi-function Lambda to query the Terraform Registry"
  integration_method     = "POST"
  integration_uri        = var.registry_invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "discovery" {
  api_id             = aws_apigatewayv2_api.registry.id
  integration_type   = "HTTP_PROXY"
  description        = "Proxy the service discovery document in S3"
  integration_method = "GET"
  integration_uri    = format("https://%s.s3.%s.amazonaws.com/%s", var.bucket_registry_id, var.bucket_registry_region, aws_s3_bucket_object.discovery_json.key)
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



################################################################################
# Import
################################################################################

resource "aws_api_gateway_stage" "import" {
  stage_name    = "live"
  rest_api_id   = aws_api_gateway_rest_api.import.id
  deployment_id = aws_api_gateway_deployment.import.id
}

resource "aws_api_gateway_deployment" "import" {
  # depends_on  = ["aws_api_gateway_integration.import"]
  rest_api_id = aws_api_gateway_rest_api.import.id
  stage_name  = "live"
}

resource "aws_api_gateway_rest_api" "import" {
  name        = format("%s-rest", var.api_name)
  description = "REST API for managing the Terraform Registry"
  tags        = var.tags

  body = templatefile(
    format("%s/import.yaml", path.module),
    {
      invoke_arn = aws_lambda_function.import.invoke_arn
      role_arn   = aws_iam_role.import_lambda.arn
    }
  )
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

resource "aws_iam_role" "import_lambda" {
  name                  = "import_lambda"
  assume_role_policy    = data.aws_iam_policy_document.lambda.json
  force_detach_policies = true
  description           = "The role used to execute the import lambda"
  tags                  = var.tags
}

resource "aws_iam_role_policy_attachment" "registry_lambda_basic_execution" {
  role       = aws_iam_role.import_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "import" {
  type        = "zip"
  source_dir  = format("%s/../../lambda/import", path.module)
  output_path = format("%s/import.zip", path.module)
}

resource "aws_lambda_function" "import" {
  filename         = data.archive_file.import.output_path
  function_name    = "import_lambda"
  role             = aws_iam_role.import_lambda.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.import.output_base64sha256
  runtime          = "nodejs12.x"
  tags             = var.tags
}
