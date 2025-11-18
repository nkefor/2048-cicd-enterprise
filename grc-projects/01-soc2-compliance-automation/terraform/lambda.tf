# Lambda Function: Evidence Collector
resource "aws_lambda_function" "evidence_collector" {
  filename      = "${path.module}/../lambda/evidence-collector.zip"
  function_name = "${local.prefix}-evidence-collector"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "index.handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  environment {
    variables = {
      EVIDENCE_BUCKET      = aws_s3_bucket.evidence.id
      EVIDENCE_TABLE       = aws_dynamodb_table.compliance_evidence.name
      CONTROL_STATUS_TABLE = aws_dynamodb_table.control_status.name
      SNS_TOPIC_ARN        = aws_sns_topic.compliance_alerts.arn
      KMS_KEY_ID           = aws_kms_key.compliance.key_id
      ENVIRONMENT          = var.environment
      TARGET_ACCOUNTS      = jsonencode(var.target_accounts)
      ASSUME_ROLE_NAME     = var.assume_role_name
    }
  }

  tracing_config {
    mode = "Active"
  }

  reserved_concurrent_executions = var.enable_lambda_reserved_concurrency ? var.reserved_concurrency_limit : -1

  tags = merge(
    local.common_tags,
    {
      Name = "${local.prefix}-evidence-collector"
      Purpose = "Evidence-Collection"
    }
  )
}

# Lambda Function: Policy Validator
resource "aws_lambda_function" "policy_validator" {
  filename      = "${path.module}/../lambda/policy-validator.zip"
  function_name = "${local.prefix}-policy-validator"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "index.handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  environment {
    variables = {
      EVIDENCE_TABLE          = aws_dynamodb_table.compliance_evidence.name
      FINDINGS_TABLE          = aws_dynamodb_table.audit_findings.name
      VIOLATIONS_TABLE        = aws_dynamodb_table.policy_violations.name
      SNS_TOPIC_ARN           = aws_sns_topic.compliance_alerts.arn
      COMPLIANCE_THRESHOLD    = var.compliance_score_threshold
      CRITICAL_THRESHOLD      = var.critical_finding_threshold
      ENABLED_TRUST_PRINCIPLES = jsonencode(var.enabled_trust_principles)
      ENABLE_HIPAA            = var.enable_hipaa_controls
      ENABLE_PCI_DSS          = var.enable_pci_dss_controls
      ENABLE_GDPR             = var.enable_gdpr_controls
    }
  }

  tracing_config {
    mode = "Active"
  }

  reserved_concurrent_executions = var.enable_lambda_reserved_concurrency ? var.reserved_concurrency_limit : -1

  tags = merge(
    local.common_tags,
    {
      Name = "${local.prefix}-policy-validator"
      Purpose = "Policy-Validation"
    }
  )
}

# Lambda Function: Audit Scanner
resource "aws_lambda_function" "audit_scanner" {
  filename      = "${path.module}/../lambda/audit-scanner.zip"
  function_name = "${local.prefix}-audit-scanner"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "index.handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  environment {
    variables = {
      FINDINGS_TABLE   = aws_dynamodb_table.audit_findings.name
      SNS_TOPIC_ARN    = aws_sns_topic.compliance_alerts.arn
      ENVIRONMENT      = var.environment
    }
  }

  tracing_config {
    mode = "Active"
  }

  reserved_concurrent_executions = var.enable_lambda_reserved_concurrency ? var.reserved_concurrency_limit : -1

  tags = merge(
    local.common_tags,
    {
      Name = "${local.prefix}-audit-scanner"
      Purpose = "Audit-Scanning"
    }
  )
}

# Lambda Function: Report Generator
resource "aws_lambda_function" "report_generator" {
  filename      = "${path.module}/../lambda/report-generator.zip"
  function_name = "${local.prefix}-report-generator"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "index.handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = 1024 # Higher memory for report generation

  environment {
    variables = {
      EVIDENCE_BUCKET      = aws_s3_bucket.evidence.id
      EVIDENCE_TABLE       = aws_dynamodb_table.compliance_evidence.name
      FINDINGS_TABLE       = aws_dynamodb_table.audit_findings.name
      CONTROL_STATUS_TABLE = aws_dynamodb_table.control_status.name
      SNS_TOPIC_ARN        = aws_sns_topic.compliance_alerts.arn
    }
  }

  tracing_config {
    mode = "Active"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.prefix}-report-generator"
      Purpose = "Report-Generation"
    }
  )
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "evidence_collector" {
  name              = "/aws/lambda/${aws_lambda_function.evidence_collector.function_name}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.compliance.arn

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "policy_validator" {
  name              = "/aws/lambda/${aws_lambda_function.policy_validator.function_name}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.compliance.arn

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "audit_scanner" {
  name              = "/aws/lambda/${aws_lambda_function.audit_scanner.function_name}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.compliance.arn

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "report_generator" {
  name              = "/aws/lambda/${aws_lambda_function.report_generator.function_name}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.compliance.arn

  tags = local.common_tags
}

# Lambda Permissions for EventBridge
resource "aws_lambda_permission" "evidence_collector" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.evidence_collector.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.compliance_scan_schedule.arn
}

resource "aws_lambda_permission" "policy_validator" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.policy_validator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.policy_validation_schedule.arn
}

resource "aws_lambda_permission" "audit_scanner" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.audit_scanner.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.audit_scan_schedule.arn
}

resource "aws_lambda_permission" "report_generator_daily" {
  statement_id  = "AllowEventBridgeInvokeDaily"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.report_generator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_report_schedule.arn
}

resource "aws_lambda_permission" "report_generator_weekly" {
  statement_id  = "AllowEventBridgeInvokeWeekly"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.report_generator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.weekly_report_schedule.arn
}

# CloudWatch Alarms for Lambda Functions
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = {
    evidence_collector = aws_lambda_function.evidence_collector.function_name
    policy_validator   = aws_lambda_function.policy_validator.function_name
    audit_scanner      = aws_lambda_function.audit_scanner.function_name
    report_generator   = aws_lambda_function.report_generator.function_name
  }

  alarm_name          = "${local.prefix}-${each.key}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Alert when Lambda function ${each.value} has errors"
  alarm_actions       = [aws_sns_topic.compliance_alerts.arn]

  dimensions = {
    FunctionName = each.value
  }

  tags = local.common_tags
}
