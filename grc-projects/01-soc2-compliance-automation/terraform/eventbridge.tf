# EventBridge Rule: Compliance Scan Schedule
resource "aws_cloudwatch_event_rule" "compliance_scan_schedule" {
  name                = "${local.prefix}-compliance-scan"
  description         = "Trigger compliance evidence collection"
  schedule_expression = "rate(${var.scan_frequency_minutes} minutes)"

  tags = merge(
    local.common_tags,
    {
      Name = "${local.prefix}-compliance-scan"
    }
  )
}

resource "aws_cloudwatch_event_target" "compliance_scan" {
  rule      = aws_cloudwatch_event_rule.compliance_scan_schedule.name
  target_id = "ComplianceScanTarget"
  arn       = aws_lambda_function.evidence_collector.arn

  input = jsonencode({
    scan_type = "incremental"
    timestamp = "$$.time"
  })
}

# EventBridge Rule: Policy Validation Schedule
resource "aws_cloudwatch_event_rule" "policy_validation_schedule" {
  name                = "${local.prefix}-policy-validation"
  description         = "Trigger policy validation checks"
  schedule_expression = "rate(${var.scan_frequency_minutes * 2} minutes)"

  tags = merge(
    local.common_tags,
    {
      Name = "${local.prefix}-policy-validation"
    }
  )
}

resource "aws_cloudwatch_event_target" "policy_validation" {
  rule      = aws_cloudwatch_event_rule.policy_validation_schedule.name
  target_id = "PolicyValidationTarget"
  arn       = aws_lambda_function.policy_validator.arn

  input = jsonencode({
    validation_type = "all"
  })
}

# EventBridge Rule: Audit Scan Schedule (Daily at 2 AM UTC)
resource "aws_cloudwatch_event_rule" "audit_scan_schedule" {
  name                = "${local.prefix}-audit-scan"
  description         = "Trigger daily audit scanning"
  schedule_expression = "cron(0 2 * * ? *)"

  tags = merge(
    local.common_tags,
    {
      Name = "${local.prefix}-audit-scan"
    }
  )
}

resource "aws_cloudwatch_event_target" "audit_scan" {
  rule      = aws_cloudwatch_event_rule.audit_scan_schedule.name
  target_id = "AuditScanTarget"
  arn       = aws_lambda_function.audit_scanner.arn

  input = jsonencode({
    scan_depth = "deep"
  })
}

# EventBridge Rule: Daily Report (Every day at 8 AM UTC)
resource "aws_cloudwatch_event_rule" "daily_report_schedule" {
  name                = "${local.prefix}-daily-report"
  description         = "Generate daily compliance report"
  schedule_expression = "cron(0 8 * * ? *)"

  tags = merge(
    local.common_tags,
    {
      Name = "${local.prefix}-daily-report"
    }
  )
}

resource "aws_cloudwatch_event_target" "daily_report" {
  rule      = aws_cloudwatch_event_rule.daily_report_schedule.name
  target_id = "DailyReportTarget"
  arn       = aws_lambda_function.report_generator.arn

  input = jsonencode({
    report_type = "daily_summary"
    recipients  = [var.alert_email]
  })
}

# EventBridge Rule: Weekly Report (Every Monday at 9 AM UTC)
resource "aws_cloudwatch_event_rule" "weekly_report_schedule" {
  name                = "${local.prefix}-weekly-report"
  description         = "Generate weekly compliance executive report"
  schedule_expression = "cron(0 9 ? * MON *)"

  tags = merge(
    local.common_tags,
    {
      Name = "${local.prefix}-weekly-report"
    }
  )
}

resource "aws_cloudwatch_event_target" "weekly_report" {
  rule      = aws_cloudwatch_event_rule.weekly_report_schedule.name
  target_id = "WeeklyReportTarget"
  arn       = aws_lambda_function.report_generator.arn

  input = jsonencode({
    report_type = "weekly_executive"
    recipients  = [var.alert_email]
    include_trends = true
  })
}

# EventBridge Rule: Config Change Detection
resource "aws_cloudwatch_event_rule" "config_change_detection" {
  name        = "${local.prefix}-config-changes"
  description = "Detect AWS Config changes for compliance monitoring"

  event_pattern = jsonencode({
    source = ["aws.config"]
    detail-type = [
      "Config Configuration Item Change",
      "Config Rules Compliance Change"
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.prefix}-config-changes"
    }
  )
}

resource "aws_cloudwatch_event_target" "config_change_scan" {
  rule      = aws_cloudwatch_event_rule.config_change_detection.name
  target_id = "ConfigChangeScanTarget"
  arn       = aws_lambda_function.evidence_collector.arn

  input_transformer {
    input_paths = {
      configRuleName = "$.detail.configRuleName"
      resourceType   = "$.detail.resourceType"
      resourceId     = "$.detail.resourceId"
    }
    input_template = jsonencode({
      scan_type     = "config_change"
      trigger_type  = "event_driven"
      config_rule   = "<configRuleName>"
      resource_type = "<resourceType>"
      resource_id   = "<resourceId>"
    })
  }
}

# EventBridge Rule: GuardDuty Findings
resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name        = "${local.prefix}-guardduty-findings"
  description = "Capture GuardDuty findings for compliance tracking"

  event_pattern = jsonencode({
    source = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.prefix}-guardduty-findings"
    }
  )
}

resource "aws_cloudwatch_event_target" "guardduty_finding_processor" {
  rule      = aws_cloudwatch_event_rule.guardduty_findings.name
  target_id = "GuardDutyFindingTarget"
  arn       = aws_lambda_function.audit_scanner.arn
}

resource "aws_lambda_permission" "guardduty_findings" {
  statement_id  = "AllowGuardDutyFindings"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.audit_scanner.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.guardduty_findings.arn
}

# EventBridge Rule: Security Hub Findings
resource "aws_cloudwatch_event_rule" "securityhub_findings" {
  name        = "${local.prefix}-securityhub-findings"
  description = "Capture Security Hub findings for compliance tracking"

  event_pattern = jsonencode({
    source = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.prefix}-securityhub-findings"
    }
  )
}

resource "aws_cloudwatch_event_target" "securityhub_finding_processor" {
  rule      = aws_cloudwatch_event_rule.securityhub_findings.name
  target_id = "SecurityHubFindingTarget"
  arn       = aws_lambda_function.audit_scanner.arn
}

resource "aws_lambda_permission" "securityhub_findings" {
  statement_id  = "AllowSecurityHubFindings"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.audit_scanner.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.securityhub_findings.arn
}
