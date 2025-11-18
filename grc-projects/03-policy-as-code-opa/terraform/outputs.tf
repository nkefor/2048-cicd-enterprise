output "policy_bucket_name" {
  description = "S3 bucket for policy storage"
  value       = aws_s3_bucket.policy_storage.id
}

output "decisions_table_name" {
  description = "DynamoDB table for policy decisions"
  value       = aws_dynamodb_table.policy_decisions.name
}

output "opa_evaluator_function_name" {
  description = "Lambda function for OPA evaluation"
  value       = aws_lambda_function.opa_evaluator.function_name
}

output "violations_topic_arn" {
  description = "SNS topic for policy violations"
  value       = aws_sns_topic.policy_violations.arn
}
