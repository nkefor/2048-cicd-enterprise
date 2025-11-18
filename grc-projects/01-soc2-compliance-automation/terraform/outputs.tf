output "evidence_bucket_name" {
  description = "S3 bucket name for compliance evidence storage"
  value       = aws_s3_bucket.evidence.id
}

output "evidence_bucket_arn" {
  description = "S3 bucket ARN for compliance evidence"
  value       = aws_s3_bucket.evidence.arn
}

output "compliance_table_name" {
  description = "DynamoDB table name for compliance tracking"
  value       = aws_dynamodb_table.compliance_evidence.name
}

output "findings_table_name" {
  description = "DynamoDB table name for audit findings"
  value       = aws_dynamodb_table.audit_findings.name
}

output "control_status_table_name" {
  description = "DynamoDB table name for control status"
  value       = aws_dynamodb_table.control_status.name
}

output "evidence_collector_function_name" {
  description = "Lambda function name for evidence collection"
  value       = aws_lambda_function.evidence_collector.function_name
}

output "policy_validator_function_name" {
  description = "Lambda function name for policy validation"
  value       = aws_lambda_function.policy_validator.function_name
}

output "audit_scanner_function_name" {
  description = "Lambda function name for audit scanning"
  value       = aws_lambda_function.audit_scanner.function_name
}

output "report_generator_function_name" {
  description = "Lambda function name for report generation"
  value       = aws_lambda_function.report_generator.function_name
}

output "sns_topic_arn" {
  description = "SNS topic ARN for compliance alerts"
  value       = aws_sns_topic.compliance_alerts.arn
}

output "kms_key_id" {
  description = "KMS key ID for encryption"
  value       = aws_kms_key.compliance.key_id
}

output "kms_key_arn" {
  description = "KMS key ARN for encryption"
  value       = aws_kms_key.compliance.arn
}

output "eventbridge_rule_name" {
  description = "EventBridge rule name for scheduled scans"
  value       = aws_cloudwatch_event_rule.compliance_scan_schedule.name
}

output "compliance_dashboard_url" {
  description = "URL to CloudWatch dashboard for compliance monitoring"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.compliance.dashboard_name}"
}

output "quicksight_dashboard_id" {
  description = "QuickSight dashboard ID (if enabled)"
  value       = var.enable_quicksight ? aws_quicksight_dashboard.compliance[0].dashboard_id : null
}

output "api_endpoint" {
  description = "API Gateway endpoint for compliance queries"
  value       = aws_apigatewayv2_api.compliance_api.api_endpoint
}

output "deployment_summary" {
  description = "Summary of deployment configuration"
  value = {
    project_name        = var.project_name
    environment         = var.environment
    region              = var.aws_region
    scan_frequency      = "${var.scan_frequency_minutes} minutes"
    retention_period    = "${var.evidence_retention_days} days (${floor(var.evidence_retention_days / 365)} years)"
    compliance_score_threshold = "${var.compliance_score_threshold}%"
    trust_principles    = var.enabled_trust_principles
    multi_account       = length(var.target_accounts) > 0
    target_accounts     = length(var.target_accounts)
    hipaa_enabled       = var.enable_hipaa_controls
    pci_dss_enabled     = var.enable_pci_dss_controls
    gdpr_enabled        = var.enable_gdpr_controls
  }
}

output "getting_started" {
  description = "Quick start instructions"
  value = <<-EOT

    ✅ SOC 2 Compliance Automation Platform Deployed Successfully!

    📊 Next Steps:

    1. Subscribe to compliance alerts:
       aws sns subscribe --topic-arn ${aws_sns_topic.compliance_alerts.arn} \
         --protocol email --notification-endpoint ${var.alert_email}

    2. Run initial compliance scan:
       aws lambda invoke --function-name ${aws_lambda_function.evidence_collector.function_name} \
         --payload '{"scan_type": "full"}' /tmp/scan-result.json

    3. View compliance dashboard:
       ${aws_cloudwatch_dashboard.compliance.dashboard_name}

    4. Query compliance status via API:
       curl ${aws_apigatewayv2_api.compliance_api.api_endpoint}/compliance/status

    5. Generate audit report:
       aws lambda invoke --function-name ${aws_lambda_function.report_generator.function_name} \
         --payload '{"report_type": "soc2", "format": "pdf"}' /tmp/report.json

    📚 Documentation:
    - Evidence Bucket: s3://${aws_s3_bucket.evidence.id}/
    - Compliance Data: DynamoDB table ${aws_dynamodb_table.compliance_evidence.name}
    - Logs: CloudWatch Log Group /aws/lambda/${local.prefix}

    💰 Estimated Monthly Cost: ~$53 USD

    🔒 Security:
    - All data encrypted with KMS key: ${aws_kms_key.compliance.key_id}
    - Evidence retention: ${var.evidence_retention_days} days
    - Automatic scans every: ${var.scan_frequency_minutes} minutes

  EOT
}
