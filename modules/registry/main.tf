data "aws_iam_policy_document" "read_dynamodb" {
  statement {
    actions   = ["dynamodb:GetItem", "dynamodb:Query"]
    resources = [var.dynamodb_registry_arn]
  }
}

data "aws_iam_policy_document" "read_s3" {
  statement {
    actions   = ["s3:Get*", "s3:List*"]
    resources = [format("%s*", var.bucket_registry_arn)]
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
  name                  = var.role_name
  assume_role_policy    = var.assume_role_policy
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
  source_dir  = format("%s/../../lambda/registry", path.module)
  output_path = format("%s/registry.zip", path.module)
}

resource "aws_lambda_function" "registry" {
  filename         = data.archive_file.registry.output_path
  function_name    = var.function_name
  role             = aws_iam_role.registry_lambda.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.registry.output_base64sha256
  runtime          = "nodejs12.x"

  environment {
    variables = {
      "TABLE"  = var.registry_name
      "BUCKET" = var.store_bucket
    }
  }

  tags = var.tags
}
