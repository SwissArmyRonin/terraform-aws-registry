output "store_bucket_id" {
  description = "The name of the registry S3 bucket"
  value = aws_s3_bucket.registry.id
}

output "registry_name" {
  description = "The name of the registry DynamoDB table"
  value = aws_dynamodb_table.registry.name
}

output "registry_endpoint" {
  description = "The registry endpoint for Terrapoint"
  value = format("%s/%s/modules", aws_apigatewayv2_api.registry.api_endpoint, aws_apigatewayv2_stage.registry.name)
}