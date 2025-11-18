output "api_gateway_url" {
  description = "API Gateway endpoint URL"
  value       = aws_apigatewayv2_api.task_api.api_endpoint
}

output "api_gateway_id" {
  description = "API Gateway ID"
  value       = aws_apigatewayv2_api.task_api.id
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.tasks.name
}

output "dynamodb_table_arn" {
  description = "DynamoDB table ARN"
  value       = aws_dynamodb_table.tasks.arn
}

output "eventbridge_bus_name" {
  description = "EventBridge custom event bus name"
  value       = aws_cloudwatch_event_bus.task_events.name
}

output "eventbridge_bus_arn" {
  description = "EventBridge custom event bus ARN"
  value       = aws_cloudwatch_event_bus.task_events.arn
}

output "step_function_arn" {
  description = "Step Functions state machine ARN"
  value       = aws_sfn_state_machine.task_approval.arn
}

output "kms_key_id" {
  description = "KMS key ID for encryption"
  value       = aws_kms_key.task_encryption.id
}

output "kms_key_arn" {
  description = "KMS key ARN for encryption"
  value       = aws_kms_key.task_encryption.arn
}

output "cloudwatch_dashboard_name" {
  description = "CloudWatch dashboard name"
  value       = aws_cloudwatch_dashboard.task_manager.dashboard_name
}

output "lambda_functions" {
  description = "Map of Lambda function names to ARNs"
  value = {
    create_task     = aws_lambda_function.create_task.arn
    get_task        = aws_lambda_function.get_task.arn
    update_task     = aws_lambda_function.update_task.arn
    delete_task     = aws_lambda_function.delete_task.arn
    list_tasks      = aws_lambda_function.list_tasks.arn
    task_created    = aws_lambda_function.task_created_handler.arn
    task_updated    = aws_lambda_function.task_updated_handler.arn
    task_completed  = aws_lambda_function.task_completed_handler.arn
  }
}

output "sns_topic_arn" {
  description = "SNS topic ARN for alarms"
  value       = var.alarm_email != "" ? aws_sns_topic.alarms[0].arn : ""
}
