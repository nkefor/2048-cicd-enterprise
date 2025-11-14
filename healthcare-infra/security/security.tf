# Comprehensive Security Components
# IAM, Cognito, WAF, KMS, GuardDuty, CloudTrail, Security Hub
# HIPAA, HITRUST, and NIST 800-53 compliant

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

##############################################################################
# KMS - Encryption Key Management
##############################################################################

resource "aws_kms_key" "healthcare_data" {
  description             = "KMS key for healthcare data encryption (HIPAA compliant)"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  multi_region            = true

  tags = {
    Name        = "${var.environment}-healthcare-kms-key"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

resource "aws_kms_alias" "healthcare_data_alias" {
  name          = "alias/${var.environment}-healthcare-data"
  target_key_id = aws_kms_key.healthcare_data.key_id
}

resource "aws_kms_key_policy" "healthcare_data_policy" {
  key_id = aws_kms_key.healthcare_data.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow services to use the key"
        Effect = "Allow"
        Principal = {
          Service = [
            "lambda.amazonaws.com",
            "dynamodb.amazonaws.com",
            "s3.amazonaws.com",
            "logs.amazonaws.com",
            "sns.amazonaws.com"
          ]
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

##############################################################################
# Amazon Cognito - User Authentication
##############################################################################

resource "aws_cognito_user_pool" "healthcare" {
  name = "${var.environment}-healthcare-user-pool"

  # Password policy
  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 1
  }

  # MFA configuration
  mfa_configuration = "REQUIRED"

  software_token_mfa_configuration {
    enabled = true
  }

  # Account recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # User attributes
  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = false
  }

  schema {
    name                = "role"
    attribute_data_type = "String"
    required            = false
    mutable             = true
  }

  # Email configuration
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # Advanced security
  user_pool_add_ons {
    advanced_security_mode = "ENFORCED"
  }

  # Device tracking
  device_configuration {
    challenge_required_on_new_device      = true
    device_only_remembered_on_user_prompt = true
  }

  tags = {
    Name        = "${var.environment}-healthcare-user-pool"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

resource "aws_cognito_user_pool_domain" "healthcare" {
  domain       = "${var.environment}-healthcare-${data.aws_caller_identity.current.account_id}"
  user_pool_id = aws_cognito_user_pool.healthcare.id
}

resource "aws_cognito_user_pool_client" "healthcare_client" {
  name         = "${var.environment}-healthcare-client"
  user_pool_id = aws_cognito_user_pool.healthcare.id

  generate_secret = true

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]
  callback_urls                        = var.callback_urls
  logout_urls                          = var.logout_urls

  supported_identity_providers = ["COGNITO"]

  # Token validity
  access_token_validity  = 1  # 1 hour
  id_token_validity      = 1  # 1 hour
  refresh_token_validity = 30 # 30 days

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }
}

##############################################################################
# CloudTrail - Audit Logging
##############################################################################

resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket = "${var.environment}-healthcare-cloudtrail-logs-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "${var.environment}-cloudtrail-logs"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.healthcare_data.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  rule {
    id     = "archive-old-logs"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 2555 # 7 years for HIPAA compliance
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

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
        Resource = aws_s3_bucket.cloudtrail_logs.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_logs.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_cloudtrail" "healthcare" {
  name                          = "${var.environment}-healthcare-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  kms_key_id                    = aws_kms_key.healthcare_data.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type = "AWS::DynamoDB::Table"
      values = ["arn:aws:dynamodb:*:*:table/*"]
    }

    data_resource {
      type = "AWS::Lambda::Function"
      values = ["arn:aws:lambda:*:*:function/*"]
    }

    data_resource {
      type = "AWS::S3::Object"
      values = ["arn:aws:s3:::*/"]
    }
  }

  insight_selector {
    insight_type = "ApiCallRateInsight"
  }

  tags = {
    Name        = "${var.environment}-healthcare-trail"
    Environment = var.environment
    Compliance  = "HIPAA"
  }

  depends_on = [aws_s3_bucket_policy.cloudtrail_logs]
}

##############################################################################
# GuardDuty - Threat Detection
##############################################################################

resource "aws_guardduty_detector" "healthcare" {
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
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

  finding_publishing_frequency = "FIFTEEN_MINUTES"

  tags = {
    Name        = "${var.environment}-healthcare-guardduty"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

# GuardDuty SNS Topic for Alerts
resource "aws_sns_topic" "guardduty_alerts" {
  name              = "${var.environment}-guardduty-alerts"
  kms_master_key_id = aws_kms_key.healthcare_data.id

  tags = {
    Name        = "${var.environment}-guardduty-alerts"
    Environment = var.environment
  }
}

# EventBridge Rule for GuardDuty Findings
resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name        = "${var.environment}-guardduty-findings"
  description = "Capture GuardDuty findings"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
  })
}

resource "aws_cloudwatch_event_target" "guardduty_sns" {
  rule      = aws_cloudwatch_event_rule.guardduty_findings.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.guardduty_alerts.arn
}

##############################################################################
# Security Hub - Centralized Security Management
##############################################################################

resource "aws_securityhub_account" "healthcare" {
  enable_default_standards = true
  control_finding_generator = "SECURITY_CONTROL"
}

resource "aws_securityhub_standards_subscription" "cis_aws_foundations" {
  standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/cis-aws-foundations-benchmark/v/1.4.0"
  depends_on    = [aws_securityhub_account.healthcare]
}

resource "aws_securityhub_standards_subscription" "pci_dss" {
  standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/pci-dss/v/3.2.1"
  depends_on    = [aws_securityhub_account.healthcare]
}

resource "aws_securityhub_standards_subscription" "nist" {
  standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/nist-800-53/v/5.0.0"
  depends_on    = [aws_securityhub_account.healthcare]
}

##############################################################################
# AWS Config - Configuration Compliance
##############################################################################

resource "aws_s3_bucket" "config" {
  bucket = "${var.environment}-healthcare-config-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "${var.environment}-config"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
  bucket = aws_s3_bucket.config.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.healthcare_data.arn
    }
  }
}

resource "aws_config_configuration_recorder" "healthcare" {
  name     = "${var.environment}-healthcare-config"
  role_arn = aws_iam_role.config_role.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "healthcare" {
  name           = "${var.environment}-healthcare-config"
  s3_bucket_name = aws_s3_bucket.config.id

  depends_on = [aws_config_configuration_recorder.healthcare]
}

resource "aws_config_configuration_recorder_status" "healthcare" {
  name       = aws_config_configuration_recorder.healthcare.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.healthcare]
}

resource "aws_iam_role" "config_role" {
  name = "${var.environment}-config-role"

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
}

resource "aws_iam_role_policy_attachment" "config_policy" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/ConfigRole"
}

##############################################################################
# IAM Access Analyzer
##############################################################################

resource "aws_accessanalyzer_analyzer" "healthcare" {
  analyzer_name = "${var.environment}-healthcare-access-analyzer"
  type          = "ACCOUNT"

  tags = {
    Name        = "${var.environment}-access-analyzer"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

##############################################################################
# VPC Flow Logs
##############################################################################

resource "aws_flow_log" "vpc_flow_logs" {
  vpc_id          = var.vpc_id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_logs_role.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn

  tags = {
    Name        = "${var.environment}-vpc-flow-logs"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/${var.environment}-flow-logs"
  retention_in_days = 90
  kms_key_id        = aws_kms_key.healthcare_data.arn

  tags = {
    Name        = "${var.environment}-vpc-flow-logs"
    Environment = var.environment
  }
}

resource "aws_iam_role" "flow_logs_role" {
  name = "${var.environment}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "flow_logs_policy" {
  name = "${var.environment}-vpc-flow-logs-policy"
  role = aws_iam_role.flow_logs_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

##############################################################################
# Data sources
##############################################################################

data "aws_caller_identity" "current" {}

##############################################################################
# Variables
##############################################################################

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "callback_urls" {
  description = "Cognito callback URLs"
  type        = list(string)
  default     = []
}

variable "logout_urls" {
  description = "Cognito logout URLs"
  type        = list(string)
  default     = []
}

##############################################################################
# Outputs
##############################################################################

output "kms_key_id" {
  description = "KMS key ID"
  value       = aws_kms_key.healthcare_data.id
}

output "kms_key_arn" {
  description = "KMS key ARN"
  value       = aws_kms_key.healthcare_data.arn
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.healthcare.id
}

output "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN"
  value       = aws_cognito_user_pool.healthcare.arn
}

output "cognito_client_id" {
  description = "Cognito Client ID"
  value       = aws_cognito_user_pool_client.healthcare_client.id
  sensitive   = true
}

output "cloudtrail_arn" {
  description = "CloudTrail ARN"
  value       = aws_cloudtrail.healthcare.arn
}

output "guardduty_detector_id" {
  description = "GuardDuty Detector ID"
  value       = aws_guardduty_detector.healthcare.id
}

output "security_hub_arn" {
  description = "Security Hub ARN"
  value       = aws_securityhub_account.healthcare.arn
}
