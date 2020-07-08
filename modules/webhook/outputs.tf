output "function_name" {
  value = aws_lambda_function.webhook.function_name
}

output "invoke_arn" {
  value = aws_lambda_function.webhook.invoke_arn
}
