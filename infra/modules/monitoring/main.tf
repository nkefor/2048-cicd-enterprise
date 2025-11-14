# Monitoring Module - Security Hub, GuardDuty, Config, Macie, CloudTrail

# CloudTrail - HIPAA Audit Logging
resource "aws_cloudtrail" "main" {
  name                          = "${var.environment}-healthcare-audit-trail"
  s3_bucket_name                = var.cloudtrail_s3_bucket
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  kms_key_id                    = var.kms_key_arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::*/"]
    }

    data_resource {
      type   = "AWS::DynamoDB::Table"
      values = ["arn:aws:dynamodb:*:${var.account_id}:table/*"]
    }

    data_resource {
      type   = "AWS::Lambda::Function"
      values = ["arn:aws:lambda:*:${var.account_id}:function/*"]
    }
  }

  insight_selector {
    insight_type = "ApiCallRateInsight"
  }

  insight_selector {
    insight_type = "ApiErrorRateInsight"
  }

  tags = {
    Name       = "${var.environment}-healthcare-audit-trail"
    Compliance = "HIPAA"
    Retention  = "6-years"
  }

  depends_on = [aws_s3_bucket_policy.cloudtrail]
}

# CloudTrail S3 Bucket Policy
resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = var.cloudtrail_s3_bucket

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = "arn:aws:s3:::${var.cloudtrail_s3_bucket}"
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${var.cloudtrail_s3_bucket}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# Amazon GuardDuty - Threat Detection
resource "aws_guardduty_detector" "main" {
  enable                       = var.enable_guardduty
  finding_publishing_frequency = "FIFTEEN_MINUTES"

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = false
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  tags = {
    Name       = "${var.environment}-guardduty"
    Compliance = "HIPAA"
  }
}

# GuardDuty Filter for Critical Findings
resource "aws_guardduty_filter" "critical_findings" {
  name        = "critical-findings"
  action      = "ARCHIVE"
  detector_id = aws_guardduty_detector.main.id
  rank        = 1

  finding_criteria {
    criterion {
      field  = "severity"
      equals = ["8", "9", "10"]
    }
  }
}

# AWS Security Hub
resource "aws_securityhub_account" "main" {
  count = var.enable_security_hub ? 1 : 0

  enable_default_standards = true
  control_finding_generator = "SECURITY_CONTROL"
  auto_enable_controls      = true
}

# Security Hub Standards
resource "aws_securityhub_standards_subscription" "cis" {
  count         = var.enable_security_hub ? 1 : 0
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:${var.region}::standards/cis-aws-foundations-benchmark/v/1.4.0"
}

resource "aws_securityhub_standards_subscription" "aws_foundational" {
  count         = var.enable_security_hub ? 1 : 0
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:${var.region}::standards/aws-foundational-security-best-practices/v/1.0.0"
}

resource "aws_securityhub_standards_subscription" "pci_dss" {
  count         = var.enable_security_hub ? 1 : 0
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:${var.region}::standards/pci-dss/v/3.2.1"
}

resource "aws_securityhub_standards_subscription" "nist_800_53" {
  count         = var.enable_security_hub ? 1 : 0
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:${var.region}::standards/nist-800-53/v/5.0.0"
}

# Security Hub Product Integration
resource "aws_securityhub_product_subscription" "guardduty" {
  count       = var.enable_security_hub ? 1 : 0
  depends_on  = [aws_securityhub_account.main]
  product_arn = "arn:aws:securityhub:${var.region}::product/aws/guardduty"
}

resource "aws_securityhub_product_subscription" "inspector" {
  count       = var.enable_security_hub ? 1 : 0
  depends_on  = [aws_securityhub_account.main]
  product_arn = "arn:aws:securityhub:${var.region}::product/aws/inspector"
}

resource "aws_securityhub_product_subscription" "macie" {
  count       = var.enable_security_hub ? 1 : 0
  depends_on  = [aws_securityhub_account.main]
  product_arn = "arn:aws:securityhub:${var.region}::product/aws/macie"
}

# AWS Config
resource "aws_config_configuration_recorder" "main" {
  count    = var.enable_config ? 1 : 0
  name     = "${var.environment}-config-recorder"
  role_arn = aws_iam_role.config[0].arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "main" {
  count          = var.enable_config ? 1 : 0
  name           = "${var.environment}-config-delivery"
  s3_bucket_name = aws_s3_bucket.config[0].id

  snapshot_delivery_properties {
    delivery_frequency = "TwentyFour_Hours"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_configuration_recorder_status" "main" {
  count      = var.enable_config ? 1 : 0
  name       = aws_config_configuration_recorder.main[0].name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.main]
}

# Config S3 Bucket
resource "aws_s3_bucket" "config" {
  count  = var.enable_config ? 1 : 0
  bucket = "${var.environment}-healthcare-config-${var.account_id}"

  tags = {
    Name       = "${var.environment}-healthcare-config"
    Compliance = "HIPAA"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
  count  = var.enable_config ? 1 : 0
  bucket = aws_s3_bucket.config[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
  }
}

resource "aws_s3_bucket_versioning" "config" {
  count  = var.enable_config ? 1 : 0
  bucket = aws_s3_bucket.config[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Config IAM Role
resource "aws_iam_role" "config" {
  count = var.enable_config ? 1 : 0
  name  = "${var.environment}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.environment}-config-role"
  }
}

resource "aws_iam_role_policy_attachment" "config" {
  count      = var.enable_config ? 1 : 0
  role       = aws_iam_role.config[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/ConfigRole"
}

# Config Rules - HIPAA Compliance
resource "aws_config_config_rule" "encrypted_volumes" {
  count = var.enable_config ? 1 : 0
  name  = "encrypted-volumes"

  source {
    owner             = "AWS"
    source_identifier = "ENCRYPTED_VOLUMES"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "s3_bucket_public_read_prohibited" {
  count = var.enable_config ? 1 : 0
  name  = "s3-bucket-public-read-prohibited"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "s3_bucket_public_write_prohibited" {
  count = var.enable_config ? 1 : 0
  name  = "s3-bucket-public-write-prohibited"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_WRITE_PROHIBITED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "dynamodb_encrypted" {
  count = var.enable_config ? 1 : 0
  name  = "dynamodb-table-encrypted-kms"

  source {
    owner             = "AWS"
    source_identifier = "DYNAMODB_TABLE_ENCRYPTED_KMS"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "cloudtrail_enabled" {
  count = var.enable_config ? 1 : 0
  name  = "cloudtrail-enabled"

  source {
    owner             = "AWS"
    source_identifier = "CLOUD_TRAIL_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "mfa_enabled" {
  count = var.enable_config ? 1 : 0
  name  = "iam-root-access-key-check"

  source {
    owner             = "AWS"
    source_identifier = "IAM_ROOT_ACCESS_KEY_CHECK"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

# Amazon Macie
resource "aws_macie2_account" "main" {
  count                        = var.enable_macie ? 1 : 0
  finding_publishing_frequency = "FIFTEEN_MINUTES"
  status                       = "ENABLED"
}

# Amazon Inspector
resource "aws_inspector2_enabler" "main" {
  account_ids    = [var.account_id]
  resource_types = ["ECR", "LAMBDA"]
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/${var.environment}/healthcare/application"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.enable_log_encryption ? var.kms_key_arn : null

  tags = {
    Name       = "${var.environment}-application-logs"
    Compliance = "HIPAA"
  }
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "guardduty_findings" {
  alarm_name          = "${var.environment}-guardduty-critical-findings"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "GuardDutyFindings"
  namespace           = "AWS/GuardDuty"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Alert on GuardDuty critical findings"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  dimensions = {
    Severity = "High"
  }

  tags = {
    Name = "${var.environment}-guardduty-alarm"
  }
}

resource "aws_cloudwatch_metric_alarm" "unauthorized_api_calls" {
  alarm_name          = "${var.environment}-unauthorized-api-calls"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "UnauthorizedAPICalls"
  namespace           = "CloudTrailMetrics"
  period              = "60"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "Alert on unauthorized API calls"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  tags = {
    Name = "${var.environment}-unauthorized-api-calls"
  }
}

# SNS Topics for Alerts
resource "aws_sns_topic" "security_alerts" {
  name              = "${var.environment}-security-alerts"
  kms_master_key_id = var.kms_key_arn

  tags = {
    Name = "${var.environment}-security-alerts"
  }
}

resource "aws_sns_topic" "compliance_alerts" {
  name              = "${var.environment}-compliance-alerts"
  kms_master_key_id = var.kms_key_arn

  tags = {
    Name = "${var.environment}-compliance-alerts"
  }
}

# EventBridge Rules for Security Events
resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name        = "${var.environment}-guardduty-findings"
  description = "Capture GuardDuty findings"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [7, 8, 9]
    }
  })

  tags = {
    Name = "${var.environment}-guardduty-findings-rule"
  }
}

resource "aws_cloudwatch_event_target" "guardduty_sns" {
  rule      = aws_cloudwatch_event_rule.guardduty_findings.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_alerts.arn
}

resource "aws_cloudwatch_event_rule" "security_hub_findings" {
  name        = "${var.environment}-security-hub-findings"
  description = "Capture Security Hub findings"

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity = {
          Label = ["CRITICAL", "HIGH"]
        }
      }
    }
  })

  tags = {
    Name = "${var.environment}-security-hub-findings-rule"
  }
}

resource "aws_cloudwatch_event_target" "security_hub_sns" {
  rule      = aws_cloudwatch_event_rule.security_hub_findings.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_alerts.arn
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.environment}-healthcare-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations"],
            [".", "Errors"],
            [".", "Duration"]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "Lambda Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApiGateway", "4XXError"],
            [".", "5XXError"],
            [".", "Count"]
          ]
          period = 300
          stat   = "Sum"
          region = var.region
          title  = "API Gateway Metrics"
        }
      },
      {
        type = "log"
        properties = {
          query   = "SOURCE '/aws/${var.environment}/healthcare/application' | fields @timestamp, @message | sort @timestamp desc | limit 20"
          region  = var.region
          title   = "Recent Application Logs"
        }
      }
    ]
  })
}
