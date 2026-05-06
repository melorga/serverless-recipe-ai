output "api_gateway_url" {
  description = "URL of the API Gateway"
  value       = "${aws_api_gateway_rest_api.recipe_api.execution_arn}/${aws_api_gateway_stage.recipe_api.stage_name}"
}

output "api_gateway_invoke_url" {
  description = "Invoke URL of the API Gateway"
  value       = aws_api_gateway_stage.recipe_api.invoke_url
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.recipe_generator.function_name
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.recipe_cache.name
}

output "cloudwatch_dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.recipe_api.dashboard_name}"
}

output "api_key_id" {
  description = "ID of the default API key. Retrieve the value with: aws apigateway get-api-key --api-key <id> --include-value"
  value       = aws_api_gateway_api_key.default.id
}

output "bedrock_model_id" {
  description = "Bedrock foundation model id used by the Lambda."
  value       = var.bedrock_model_id
}
