# Main Terraform Outputs

# VPC Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.networking.private_subnet_ids
}

# Security Outputs
output "kms_key_arn" {
  description = "KMS Key ARN for PHI encryption"
  value       = module.security.kms_key_arn
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = module.security.cognito_user_pool_id
}

output "cognito_user_pool_client_id" {
  description = "Cognito User Pool Client ID"
  value       = module.security.cognito_user_pool_client_id
  sensitive   = true
}

output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN"
  value       = module.security.waf_web_acl_arn
}

# API Gateway Outputs
output "api_gateway_url" {
  description = "API Gateway URL"
  value       = module.compute.api_gateway_url
}

output "api_gateway_id" {
  description = "API Gateway ID"
  value       = module.compute.api_gateway_id
}

# Step Functions Outputs
output "step_functions_state_machine_arn" {
  description = "Step Functions State Machine ARN"
  value       = module.compute.step_functions_state_machine_arn
}

# Data Outputs
output "dynamodb_table_names" {
  description = "DynamoDB table names"
  value       = module.data.dynamodb_table_names
}

output "s3_bucket_names" {
  description = "S3 bucket names"
  value       = module.data.s3_bucket_names
}

# Monitoring Outputs
output "cloudtrail_arn" {
  description = "CloudTrail ARN"
  value       = module.monitoring.cloudtrail_arn
}

output "guardduty_detector_id" {
  description = "GuardDuty Detector ID"
  value       = module.monitoring.guardduty_detector_id
}

output "security_hub_arn" {
  description = "Security Hub ARN"
  value       = module.monitoring.security_hub_arn
}

output "security_alerts_topic_arn" {
  description = "Security Alerts SNS Topic ARN"
  value       = module.monitoring.security_alerts_topic_arn
}

# Dashboard URLs
output "cloudwatch_dashboard_url" {
  description = "CloudWatch Dashboard URL"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${local.region}#dashboards:name=${var.environment}-healthcare-dashboard"
}

output "security_hub_url" {
  description = "Security Hub Console URL"
  value       = "https://console.aws.amazon.com/securityhub/home?region=${local.region}"
}

output "step_functions_console_url" {
  description = "Step Functions Console URL"
  value       = "https://console.aws.amazon.com/states/home?region=${local.region}#/statemachines/view/${module.compute.step_functions_state_machine_arn}"
}

# Governance Outputs
output "scp_policy_ids" {
  description = "Service Control Policy IDs"
  value       = module.governance.scp_policy_ids
}

output "scp_count" {
  description = "Number of SCPs deployed"
  value       = module.governance.scp_count
}

# Quick Start Commands
output "quick_start_guide" {
  description = "Quick start commands"
  value = <<-EOT

    ========================================
    Healthcare DevOps Platform - Quick Start
    ========================================

    API Gateway Endpoint:
    ${module.compute.api_gateway_url}

    Cognito User Pool ID:
    ${module.security.cognito_user_pool_id}

    Step Functions State Machine:
    ${module.compute.step_functions_state_machine_arn}

    Next Steps:
    1. Configure Cognito users
    2. Subscribe to SNS topics for alerts
    3. Review Security Hub findings
    4. Test Step Functions workflow
    5. Configure CloudWatch dashboards

    Monitoring URLs:
    - CloudWatch: ${local.region == "us-east-1" ? "https://console.aws.amazon.com/cloudwatch/home?region=us-east-1" : "https://console.aws.amazon.com/cloudwatch/"}
    - Security Hub: https://console.aws.amazon.com/securityhub/
    - GuardDuty: https://console.aws.amazon.com/guardduty/

    ========================================
  EOT
}
