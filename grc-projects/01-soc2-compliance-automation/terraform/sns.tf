# SNS Topic for Compliance Alerts
resource "aws_sns_topic" "compliance_alerts" {
  name              = "${local.prefix}-alerts"
  display_name      = "SOC 2 Compliance Alerts"
  kms_master_key_id = aws_kms_key.compliance.id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.prefix}-alerts"
      Purpose = "Compliance-Alerting"
    }
  )
}

# SNS Topic Policy
resource "aws_sns_topic_policy" "compliance_alerts" {
  arn = aws_sns_topic.compliance_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLambdaPublish"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sns:Publish"
        Resource = aws_sns_topic.compliance_alerts.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = [
              aws_lambda_function.evidence_collector.arn,
              aws_lambda_function.policy_validator.arn,
              aws_lambda_function.audit_scanner.arn,
              aws_lambda_function.report_generator.arn
            ]
          }
        }
      },
      {
        Sid    = "AllowCloudWatchPublish"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action = "sns:Publish"
        Resource = aws_sns_topic.compliance_alerts.arn
      }
    ]
  })
}

# Email subscription (requires manual confirmation)
resource "aws_sns_topic_subscription" "compliance_email" {
  topic_arn = aws_sns_topic.compliance_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Slack subscription (if webhook URL provided)
resource "aws_sns_topic_subscription" "compliance_slack" {
  count     = var.alert_slack_webhook != "" ? 1 : 0
  topic_arn = aws_sns_topic.compliance_alerts.arn
  protocol  = "https"
  endpoint  = var.alert_slack_webhook
}

# SNS Topic for Critical Findings
resource "aws_sns_topic" "critical_findings" {
  name              = "${local.prefix}-critical-findings"
  display_name      = "SOC 2 Critical Findings"
  kms_master_key_id = aws_kms_key.compliance.id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.prefix}-critical-findings"
      Purpose = "Critical-Findings-Alerting"
      Severity = "CRITICAL"
    }
  )
}

resource "aws_sns_topic_subscription" "critical_findings_email" {
  topic_arn = aws_sns_topic.critical_findings.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# CloudWatch Log Metric Filter for Critical Findings
resource "aws_cloudwatch_log_metric_filter" "critical_findings" {
  name           = "${local.prefix}-critical-findings"
  log_group_name = aws_cloudwatch_log_group.policy_validator.name
  pattern        = "[time, request_id, level=ERROR*, msg=\"Critical*\"]"

  metric_transformation {
    name      = "CriticalFindings"
    namespace = "SOC2/Compliance"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "critical_findings_threshold" {
  alarm_name          = "${local.prefix}-critical-findings-threshold"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CriticalFindings"
  namespace           = "SOC2/Compliance"
  period              = 300
  statistic           = "Sum"
  threshold           = var.critical_finding_threshold
  alarm_description   = "Alert when critical findings exceed threshold"
  alarm_actions       = [aws_sns_topic.critical_findings.arn]
  treat_missing_data  = "notBreaching"

  tags = local.common_tags
}
