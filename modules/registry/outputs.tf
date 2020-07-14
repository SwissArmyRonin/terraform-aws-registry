output "function_name" {
  value = aws_lambda_function.registry.function_name
}

output "invoke_arn" {
  value = aws_lambda_function.registry.invoke_arn
}
