terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "grc/aws-security-audit/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.primary_region

  default_tags {
    tags = {
      Project     = "AWS-Security-Audit"
      ManagedBy   = "Terraform"
      Environment = var.environment
      CostCenter  = "Security"
    }
  }
}

# Additional provider for alternate regions
provider "aws" {
  alias  = "secondary"
  region = var.secondary_region
}

#------------------------------------------------------------------------------
# KMS Key for Encryption
#------------------------------------------------------------------------------
resource "aws_kms_key" "security_audit" {
  description             = "KMS key for AWS Security Audit encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name = "security-audit-kms-key"
  }
}

resource "aws_kms_alias" "security_audit" {
  name          = "alias/security-audit"
  target_key_id = aws_kms_key.security_audit.key_id
}

#------------------------------------------------------------------------------
# S3 Bucket for Evidence and Remediation Logs
#------------------------------------------------------------------------------
resource "aws_s3_bucket" "evidence" {
  bucket = "${var.project_name}-evidence-${var.environment}-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "Security Audit Evidence Bucket"
    Compliance  = "CIS-AWS-Foundations"
    Retention   = "7-years"
  }
}

resource "aws_s3_bucket_versioning" "evidence" {
  bucket = aws_s3_bucket.evidence.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "evidence" {
  bucket = aws_s3_bucket.evidence.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.security_audit.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "evidence" {
  bucket = aws_s3_bucket.evidence.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "evidence" {
  bucket = aws_s3_bucket.evidence.id

  target_bucket = aws_s3_bucket.evidence.id
  target_prefix = "access-logs/"
}

resource "aws_s3_bucket_lifecycle_configuration" "evidence" {
  bucket = aws_s3_bucket.evidence.id

  rule {
    id     = "evidence-retention"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    expiration {
      days = 2555  # 7 years
    }
  }
}

#------------------------------------------------------------------------------
# DynamoDB Tables for Finding Storage
#------------------------------------------------------------------------------
resource "aws_dynamodb_table" "security_findings" {
  name           = "${var.project_name}-findings-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "finding_id"
  range_key      = "timestamp"

  attribute {
    name = "finding_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  attribute {
    name = "severity"
    type = "S"
  }

  attribute {
    name = "account_id"
    type = "S"
  }

  global_secondary_index {
    name            = "severity-index"
    hash_key        = "severity"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "account-index"
    hash_key        = "account_id"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.security_audit.arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = "Security Findings Table"
  }
}

resource "aws_dynamodb_table" "remediation_history" {
  name           = "${var.project_name}-remediation-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "remediation_id"
  range_key      = "timestamp"

  attribute {
    name = "remediation_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  attribute {
    name = "finding_id"
    type = "S"
  }

  global_secondary_index {
    name            = "finding-index"
    hash_key        = "finding_id"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.security_audit.arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = "Remediation History Table"
  }
}

resource "aws_dynamodb_table" "compliance_score" {
  name           = "${var.project_name}-compliance-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "account_id"
  range_key      = "date"

  attribute {
    name = "account_id"
    type = "S"
  }

  attribute {
    name = "date"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.security_audit.arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = "Compliance Score Table"
  }
}

#------------------------------------------------------------------------------
# IAM Role for Auto-Remediation Lambda
#------------------------------------------------------------------------------
resource "aws_iam_role" "auto_remediation" {
  name = "${var.project_name}-auto-remediation-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "Auto-Remediation Lambda Role"
  }
}

resource "aws_iam_role_policy" "auto_remediation" {
  name = "auto-remediation-policy"
  role = aws_iam_role.auto_remediation.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "securityhub:GetFindings",
          "securityhub:BatchUpdateFindings"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutBucketPublicAccessBlock",
          "s3:PutBucketEncryption",
          "s3:PutBucketVersioning",
          "s3:PutBucketLogging",
          "s3:GetBucketPublicAccessBlock"
        ]
        Resource = "arn:aws:s3:::*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:RevokeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:DescribeSecurityGroups",
          "ec2:ModifyInstanceAttribute"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:UpdateAccountPasswordPolicy",
          "iam:DeleteAccessKey",
          "iam:UpdateAccessKey",
          "iam:CreateAccessKey"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem"
        ]
        Resource = [
          aws_dynamodb_table.security_findings.arn,
          aws_dynamodb_table.remediation_history.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.security_alerts.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.security_audit.arn
      }
    ]
  })
}

#------------------------------------------------------------------------------
# Lambda Function - Auto-Remediation
#------------------------------------------------------------------------------
resource "aws_lambda_function" "auto_remediation" {
  filename      = "${path.module}/../lambda/auto_remediation.zip"
  function_name = "${var.project_name}-auto-remediation-${var.environment}"
  role          = aws_iam_role.auto_remediation.arn
  handler       = "auto_remediation.lambda_handler"
  runtime       = "python3.11"
  timeout       = 300
  memory_size   = 512

  environment {
    variables = {
      FINDINGS_TABLE       = aws_dynamodb_table.security_findings.name
      REMEDIATION_TABLE    = aws_dynamodb_table.remediation_history.name
      EVIDENCE_BUCKET      = aws_s3_bucket.evidence.id
      SNS_TOPIC_ARN       = aws_sns_topic.security_alerts.arn
      AUTO_REMEDIATE_CRITICAL = var.auto_remediate_critical
      AUTO_REMEDIATE_HIGH     = var.auto_remediate_high
      AUTO_REMEDIATE_MEDIUM   = var.auto_remediate_medium
    }
  }

  tags = {
    Name = "Auto-Remediation Lambda"
  }
}

resource "aws_cloudwatch_log_group" "auto_remediation" {
  name              = "/aws/lambda/${aws_lambda_function.auto_remediation.function_name}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.security_audit.arn
}

#------------------------------------------------------------------------------
# Lambda Function - Risk Scoring
#------------------------------------------------------------------------------
resource "aws_iam_role" "risk_scoring" {
  name = "${var.project_name}-risk-scoring-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "risk_scoring" {
  name = "risk-scoring-policy"
  role = aws_iam_role.risk_scoring.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "securityhub:GetFindings"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.security_findings.arn,
          aws_dynamodb_table.compliance_score.arn
        ]
      }
    ]
  })
}

resource "aws_lambda_function" "risk_scoring" {
  filename      = "${path.module}/../lambda/risk_scoring.zip"
  function_name = "${var.project_name}-risk-scoring-${var.environment}"
  role          = aws_iam_role.risk_scoring.arn
  handler       = "risk_scoring.lambda_handler"
  runtime       = "python3.11"
  timeout       = 180
  memory_size   = 256

  environment {
    variables = {
      FINDINGS_TABLE    = aws_dynamodb_table.security_findings.name
      COMPLIANCE_TABLE  = aws_dynamodb_table.compliance_score.name
    }
  }

  tags = {
    Name = "Risk Scoring Lambda"
  }
}

resource "aws_cloudwatch_log_group" "risk_scoring" {
  name              = "/aws/lambda/${aws_lambda_function.risk_scoring.function_name}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.security_audit.arn
}

#------------------------------------------------------------------------------
# EventBridge Rules for Security Hub Findings
#------------------------------------------------------------------------------
resource "aws_cloudwatch_event_rule" "security_hub_findings" {
  name        = "${var.project_name}-security-findings-${var.environment}"
  description = "Capture Security Hub findings for auto-remediation"

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Compliance = {
          Status = ["FAILED"]
        }
      }
    }
  })

  tags = {
    Name = "Security Hub Findings Rule"
  }
}

resource "aws_cloudwatch_event_target" "auto_remediation" {
  rule      = aws_cloudwatch_event_rule.security_hub_findings.name
  target_id = "AutoRemediationLambda"
  arn       = aws_lambda_function.auto_remediation.arn
}

resource "aws_lambda_permission" "allow_eventbridge_auto_remediation" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auto_remediation.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.security_hub_findings.arn
}

resource "aws_cloudwatch_event_target" "risk_scoring" {
  rule      = aws_cloudwatch_event_rule.security_hub_findings.name
  target_id = "RiskScoringLambda"
  arn       = aws_lambda_function.risk_scoring.arn
}

resource "aws_lambda_permission" "allow_eventbridge_risk_scoring" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.risk_scoring.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.security_hub_findings.arn
}

#------------------------------------------------------------------------------
# EventBridge Scheduled Rules for Daily Scans
#------------------------------------------------------------------------------
resource "aws_cloudwatch_event_rule" "daily_compliance_scan" {
  name                = "${var.project_name}-daily-scan-${var.environment}"
  description         = "Daily compliance score calculation"
  schedule_expression = "cron(0 6 * * ? *)"  # 6 AM UTC daily

  tags = {
    Name = "Daily Compliance Scan"
  }
}

resource "aws_cloudwatch_event_target" "daily_compliance_scan" {
  rule      = aws_cloudwatch_event_rule.daily_compliance_scan.name
  target_id = "RiskScoringLambda"
  arn       = aws_lambda_function.risk_scoring.arn
}

resource "aws_lambda_permission" "allow_eventbridge_daily_scan" {
  statement_id  = "AllowExecutionFromEventBridgeDaily"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.risk_scoring.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_compliance_scan.arn
}

#------------------------------------------------------------------------------
# SNS Topic for Security Alerts
#------------------------------------------------------------------------------
resource "aws_sns_topic" "security_alerts" {
  name              = "${var.project_name}-alerts-${var.environment}"
  display_name      = "AWS Security Audit Alerts"
  kms_master_key_id = aws_kms_key.security_audit.id

  tags = {
    Name = "Security Alerts Topic"
  }
}

resource "aws_sns_topic_subscription" "security_email" {
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

resource "aws_sns_topic_policy" "security_alerts" {
  arn = aws_sns_topic.security_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.security_alerts.arn
      }
    ]
  })
}

#------------------------------------------------------------------------------
# CloudWatch Alarms
#------------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "critical_findings" {
  alarm_name          = "${var.project_name}-critical-findings-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CriticalFindings"
  namespace           = "AWS/SecurityHub"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Alert when critical security findings detected"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  tags = {
    Name = "Critical Findings Alarm"
  }
}

resource "aws_cloudwatch_metric_alarm" "remediation_failures" {
  alarm_name          = "${var.project_name}-remediation-failures-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "Alert when auto-remediation failures exceed threshold"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  dimensions = {
    FunctionName = aws_lambda_function.auto_remediation.function_name
  }

  tags = {
    Name = "Remediation Failures Alarm"
  }
}

#------------------------------------------------------------------------------
# Data Sources
#------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}
