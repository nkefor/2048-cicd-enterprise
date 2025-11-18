# DynamoDB Table for Compliance Evidence
resource "aws_dynamodb_table" "compliance_evidence" {
  name           = "${local.prefix}-evidence"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "control_id"
  range_key      = "timestamp"

  attribute {
    name = "control_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  attribute {
    name = "trust_principle"
    type = "S"
  }

  attribute {
    name = "compliance_status"
    type = "S"
  }

  global_secondary_index {
    name            = "trust-principle-index"
    hash_key        = "trust_principle"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "status-index"
    hash_key        = "compliance_status"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.compliance.arn
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.prefix}-evidence"
      Purpose = "Compliance-Evidence-Tracking"
    }
  )
}

# DynamoDB Table for Audit Findings
resource "aws_dynamodb_table" "audit_findings" {
  name           = "${local.prefix}-findings"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "finding_id"
  range_key      = "discovered_at"

  attribute {
    name = "finding_id"
    type = "S"
  }

  attribute {
    name = "discovered_at"
    type = "N"
  }

  attribute {
    name = "severity"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "resource_id"
    type = "S"
  }

  global_secondary_index {
    name            = "severity-index"
    hash_key        = "severity"
    range_key       = "discovered_at"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "status-index"
    hash_key        = "status"
    range_key       = "discovered_at"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "resource-index"
    hash_key        = "resource_id"
    range_key       = "discovered_at"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.compliance.arn
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.prefix}-findings"
      Purpose = "Audit-Findings-Tracking"
    }
  )
}

# DynamoDB Table for Control Status
resource "aws_dynamodb_table" "control_status" {
  name           = "${local.prefix}-control-status"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "control_id"

  attribute {
    name = "control_id"
    type = "S"
  }

  attribute {
    name = "last_check"
    type = "N"
  }

  attribute {
    name = "category"
    type = "S"
  }

  global_secondary_index {
    name            = "category-index"
    hash_key        = "category"
    range_key       = "last_check"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "last-check-index"
    hash_key        = "control_id"
    range_key       = "last_check"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.compliance.arn
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.prefix}-control-status"
      Purpose = "Control-Status-Tracking"
    }
  )
}

# DynamoDB Table for Policy Violations
resource "aws_dynamodb_table" "policy_violations" {
  name           = "${local.prefix}-policy-violations"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "violation_id"
  range_key      = "detected_at"

  attribute {
    name = "violation_id"
    type = "S"
  }

  attribute {
    name = "detected_at"
    type = "N"
  }

  attribute {
    name = "policy_name"
    type = "S"
  }

  attribute {
    name = "remediation_status"
    type = "S"
  }

  global_secondary_index {
    name            = "policy-index"
    hash_key        = "policy_name"
    range_key       = "detected_at"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "remediation-index"
    hash_key        = "remediation_status"
    range_key       = "detected_at"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.compliance.arn
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.prefix}-policy-violations"
      Purpose = "Policy-Violation-Tracking"
    }
  )
}

# CloudWatch Alarms for DynamoDB
resource "aws_cloudwatch_metric_alarm" "dynamodb_read_throttle" {
  for_each = {
    evidence   = aws_dynamodb_table.compliance_evidence.name
    findings   = aws_dynamodb_table.audit_findings.name
    controls   = aws_dynamodb_table.control_status.name
    violations = aws_dynamodb_table.policy_violations.name
  }

  alarm_name          = "${local.prefix}-${each.key}-read-throttle"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ReadThrottleEvents"
  namespace           = "AWS/DynamoDB"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Alert when DynamoDB table ${each.value} experiences read throttling"
  alarm_actions       = [aws_sns_topic.compliance_alerts.arn]

  dimensions = {
    TableName = each.value
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "dynamodb_write_throttle" {
  for_each = {
    evidence   = aws_dynamodb_table.compliance_evidence.name
    findings   = aws_dynamodb_table.audit_findings.name
    controls   = aws_dynamodb_table.control_status.name
    violations = aws_dynamodb_table.policy_violations.name
  }

  alarm_name          = "${local.prefix}-${each.key}-write-throttle"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "WriteThrottleEvents"
  namespace           = "AWS/DynamoDB"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Alert when DynamoDB table ${each.value} experiences write throttling"
  alarm_actions       = [aws_sns_topic.compliance_alerts.arn]

  dimensions = {
    TableName = each.value
  }

  tags = local.common_tags
}
