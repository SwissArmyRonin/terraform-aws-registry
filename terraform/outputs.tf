output "store_bucket_id" {
  description = "The name of the registry S3 bucket"
  value       = aws_s3_bucket.registry.id
}

output "registry_name" {
  description = "The name of the registry DynamoDB table"
  value       = aws_dynamodb_table.registry.name
}

output "endpoint_root" {
  description = "The root address of registry endpoints"
  value       = local.endpoint_root
}