# Compute Module Outputs

output "api_gateway_id" {
  description = "API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.healthcare.id
}

output "api_gateway_url" {
  description = "API Gateway URL"
  value       = "${aws_api_gateway_stage.healthcare.invoke_url}/patients"
}

output "api_gateway_stage_name" {
  description = "API Gateway stage name"
  value       = aws_api_gateway_stage.healthcare.stage_name
}

output "step_functions_state_machine_arn" {
  description = "Step Functions State Machine ARN"
  value       = aws_sfn_state_machine.patient_workflow.arn
}

output "lambda_function_arns" {
  description = "Map of Lambda function ARNs"
  value = {
    patient_intake                = aws_lambda_function.patient_intake.arn
    insurance_eligibility         = aws_lambda_function.insurance_eligibility.arn
    lab_scheduler                 = aws_lambda_function.lab_scheduler.arn
    comprehend_medical_extraction = aws_lambda_function.comprehend_medical_extraction.arn
    billing_generator             = aws_lambda_function.billing_generator.arn
    provider_notification         = aws_lambda_function.provider_notification.arn
    claim_submission              = aws_lambda_function.claim_submission.arn
  }
}

output "manual_review_topic_arn" {
  description = "SNS Topic ARN for manual review notifications"
  value       = aws_sns_topic.manual_review.arn
}

output "intake_failure_topic_arn" {
  description = "SNS Topic ARN for intake failure notifications"
  value       = aws_sns_topic.intake_failure.arn
}
