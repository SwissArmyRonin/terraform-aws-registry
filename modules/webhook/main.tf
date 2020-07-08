data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_iam_policy_document" "write_dynamodb" {
  statement {
    actions   = ["dynamodb:PutItem"]
    resources = [var.dynamodb_registry_arn]
  }
}

data "aws_iam_policy_document" "write_s3" {
  statement {
    actions   = ["s3:PutObject"]
    resources = [format("%s*", var.bucket_registry_arn)]
  }
}

data "aws_iam_policy_document" "read_ssm" {
  statement {
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = [format("arn:aws:ssm:%s:%s:parameter/%s/*", data.aws_region.current.name, data.aws_caller_identity.current.account_id, var.ssm_prefix)]
  }
}

resource "aws_iam_policy" "write_s3" {
  name   = format("s3-write-%s", var.store_bucket)
  policy = data.aws_iam_policy_document.write_s3.json
}

resource "aws_iam_policy" "read_ssm" {
  name   = format("read-ssm-%s", var.function_name)
  policy = data.aws_iam_policy_document.read_ssm.json
}

resource "aws_iam_policy" "write_dynamodb" {
  name   = format("dynamodb-write-%s", var.registry_name)
  policy = data.aws_iam_policy_document.write_dynamodb.json
}

resource "aws_iam_role" "webhook_lambda" {
  name                  = var.role_name
  assume_role_policy    = var.assume_role_policy
  force_detach_policies = true
  description           = "The role used to execute the webhook lambda"
  tags                  = var.tags
}

resource "aws_iam_role_policy_attachment" "write_dynamodb" {
  role       = aws_iam_role.webhook_lambda.name
  policy_arn = aws_iam_policy.write_dynamodb.arn
}

resource "aws_iam_role_policy_attachment" "read_ssm" {
  role       = aws_iam_role.webhook_lambda.name
  policy_arn = aws_iam_policy.read_ssm.arn
}

resource "aws_iam_role_policy_attachment" "write_s3" {
  role       = aws_iam_role.webhook_lambda.name
  policy_arn = aws_iam_policy.write_s3.arn
}

resource "aws_iam_role_policy_attachment" "webhook_lambda_basic_execution" {
  role       = aws_iam_role.webhook_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "null_resource" "npm_install" {
  provisioner "local-exec" {
    command     = "rm -rf node_modules && npm install --only=prod"
    working_dir = format("%s/../../lambda/webhook", path.module)
  }
}

data "archive_file" "webhook" {
  type        = "zip"
  source_dir  = format("%s/../../lambda/webhook", path.module)
  output_path = format("%s/webhook.zip", path.module)
  depends_on  = [null_resource.npm_install]
}

resource "aws_lambda_function" "webhook" {
  filename         = data.archive_file.webhook.output_path
  function_name    = var.function_name
  role             = aws_iam_role.webhook_lambda.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.webhook.output_base64sha256
  runtime          = "nodejs12.x"
  timeout          = 300 # 5 mins, 900 seconds is max

  environment {
    variables = {
      TABLE      = var.registry_name
      BUCKET     = var.store_bucket
      SSM_PREFIX = var.ssm_prefix
    }
  }

  tags = var.tags
}

resource "aws_ssm_parameter" "access_token" {
  for_each    = var.access_tokens
  name        = format("/%s/access_token/%s", var.ssm_prefix, each.key)
  description = "GitHub access token"
  type        = "SecureString"
  value       = each.value
  tags        = var.tags
}

resource "aws_ssm_parameter" "github_secret" {
  name        = format("/%s/github_secret", var.ssm_prefix)
  description = "GitHub webhook secret"
  type        = "SecureString"
  value       = var.github_secret
  tags        = var.tags
}
