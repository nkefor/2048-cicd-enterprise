# KMS Key for encrypting compliance evidence and data
resource "aws_kms_key" "compliance" {
  description             = "KMS key for SOC 2 compliance evidence encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.prefix}-compliance-key"
      Purpose = "Evidence-Encryption"
    }
  )
}

resource "aws_kms_alias" "compliance" {
  name          = "alias/${local.prefix}-compliance"
  target_key_id = aws_kms_key.compliance.key_id
}

# KMS Key Policy
resource "aws_kms_key_policy" "compliance" {
  key_id = aws_kms_key.compliance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Lambda to use the key"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = [
              "s3.${local.region}.amazonaws.com",
              "dynamodb.${local.region}.amazonaws.com"
            ]
          }
        }
      },
      {
        Sid    = "Allow S3 to use the key"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${local.region}.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })
}

# CloudWatch Alarm for KMS key usage
resource "aws_cloudwatch_metric_alarm" "kms_key_disabled" {
  alarm_name          = "${local.prefix}-kms-key-disabled"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "KeyState"
  namespace           = "AWS/KMS"
  period              = 300
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "Alert when KMS key is disabled"
  alarm_actions       = [aws_sns_topic.compliance_alerts.arn]

  dimensions = {
    KeyId = aws_kms_key.compliance.key_id
  }

  tags = local.common_tags
}
