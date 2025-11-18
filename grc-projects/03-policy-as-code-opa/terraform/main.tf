terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "Policy-as-Code-OPA"
      ManagedBy   = "Terraform"
      Environment = var.environment
    }
  }
}

#------------------------------------------------------------------------------
# S3 Bucket for Policy Storage
#------------------------------------------------------------------------------
resource "aws_s3_bucket" "policy_storage" {
  bucket = "${var.project_name}-policies-${var.environment}-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "policy_storage" {
  bucket = aws_s3_bucket.policy_storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "policy_storage" {
  bucket = aws_s3_bucket.policy_storage.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

#------------------------------------------------------------------------------
# DynamoDB for Policy Decision Logging
#------------------------------------------------------------------------------
resource "aws_dynamodb_table" "policy_decisions" {
  name           = "${var.project_name}-decisions-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "decision_id"
  range_key      = "timestamp"

  attribute {
    name = "decision_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  attribute {
    name = "policy_name"
    type = "S"
  }

  global_secondary_index {
    name            = "policy-index"
    hash_key        = "policy_name"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }
}

#------------------------------------------------------------------------------
# Lambda for OPA Policy Evaluation
#------------------------------------------------------------------------------
resource "aws_iam_role" "opa_evaluator" {
  name = "${var.project_name}-evaluator-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "opa_evaluator" {
  name = "opa-evaluator-policy"
  role = aws_iam_role.opa_evaluator.id

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
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.policy_storage.arn,
          "${aws_s3_bucket.policy_storage.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.policy_decisions.arn
      }
    ]
  })
}

resource "aws_lambda_function" "opa_evaluator" {
  filename      = "${path.module}/../lambda/opa_evaluator.zip"
  function_name = "${var.project_name}-evaluator-${var.environment}"
  role          = aws_iam_role.opa_evaluator.arn
  handler       = "opa_evaluator.lambda_handler"
  runtime       = "python3.11"
  timeout       = 60
  memory_size   = 512

  environment {
    variables = {
      POLICY_BUCKET    = aws_s3_bucket.policy_storage.id
      DECISIONS_TABLE  = aws_dynamodb_table.policy_decisions.name
      OPA_BUNDLE_PATH  = "policies/bundle.tar.gz"
    }
  }
}

resource "aws_cloudwatch_log_group" "opa_evaluator" {
  name              = "/aws/lambda/${aws_lambda_function.opa_evaluator.function_name}"
  retention_in_days = 30
}

#------------------------------------------------------------------------------
# SNS Topic for Policy Violations
#------------------------------------------------------------------------------
resource "aws_sns_topic" "policy_violations" {
  name = "${var.project_name}-violations-${var.environment}"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.policy_violations.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

#------------------------------------------------------------------------------
# CloudWatch Alarms
#------------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "high_violation_rate" {
  alarm_name          = "${var.project_name}-high-violations-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "PolicyViolations"
  namespace           = "PolicyAsCode"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.violation_threshold
  alarm_actions       = [aws_sns_topic.policy_violations.arn]
}

data "aws_caller_identity" "current" {}
