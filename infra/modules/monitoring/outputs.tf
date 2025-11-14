# Monitoring Module Outputs

output "cloudtrail_arn" {
  description = "CloudTrail ARN"
  value       = aws_cloudtrail.main.arn
}

output "guardduty_detector_id" {
  description = "GuardDuty Detector ID"
  value       = aws_guardduty_detector.main.id
}

output "security_hub_arn" {
  description = "Security Hub ARN"
  value       = var.enable_security_hub ? aws_securityhub_account.main[0].arn : null
}

output "config_recorder_name" {
  description = "AWS Config Recorder Name"
  value       = var.enable_config ? aws_config_configuration_recorder.main[0].name : null
}

output "macie_account_id" {
  description = "Macie Account ID"
  value       = var.enable_macie ? aws_macie2_account.main[0].id : null
}

output "security_alerts_topic_arn" {
  description = "Security Alerts SNS Topic ARN"
  value       = aws_sns_topic.security_alerts.arn
}

output "compliance_alerts_topic_arn" {
  description = "Compliance Alerts SNS Topic ARN"
  value       = aws_sns_topic.compliance_alerts.arn
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch Log Group Name"
  value       = aws_cloudwatch_log_group.application.name
}

output "dashboard_name" {
  description = "CloudWatch Dashboard Name"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}
