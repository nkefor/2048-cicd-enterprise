# Amazon Comprehend Medical Integration
# AI-driven medical data extraction

# Lambda Function for Comprehend Medical
resource "aws_lambda_function" "comprehend_medical" {
  filename         = "comprehend-medical-lambda.zip"
  function_name    = "${var.environment}-comprehend-medical"
  role            = aws_iam_role.comprehend_medical_lambda_role.arn
  handler         = "comprehend-medical-lambda.lambda_handler"
  source_code_hash = filebase64sha256("comprehend-medical-lambda.zip")
  runtime         = "python3.11"
  timeout         = 300
  memory_size     = 512

  environment {
    variables = {
      PATIENT_DATA_TABLE = aws_dynamodb_table.patients.name
      ENTITIES_TABLE     = aws_dynamodb_table.medical_entities.name
      KMS_KEY_ID         = aws_kms_key.healthcare_data.id
      ENVIRONMENT        = var.environment
    }
  }

  tracing_config {
    mode = "Active"
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  tags = {
    Name        = "${var.environment}-comprehend-medical"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

# IAM Role for Comprehend Medical Lambda
resource "aws_iam_role" "comprehend_medical_lambda_role" {
  name = "${var.environment}-comprehend-medical-lambda-role"

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
    Name        = "${var.environment}-comprehend-medical-lambda-role"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

# IAM Policy for Comprehend Medical Lambda
resource "aws_iam_role_policy" "comprehend_medical_lambda_policy" {
  name = "${var.environment}-comprehend-medical-lambda-policy"
  role = aws_iam_role.comprehend_medical_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "comprehendmedical:DetectEntitiesV2",
          "comprehendmedical:DetectPHI",
          "comprehendmedical:InferICD10CM",
          "comprehendmedical:InferRxNorm",
          "comprehendmedical:InferSNOMEDCT"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query"
        ]
        Resource = [
          aws_dynamodb_table.patients.arn,
          aws_dynamodb_table.medical_entities.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.healthcare_data.arn
      },
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
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      }
    ]
  })
}

# CloudWatch Log Group for Comprehend Medical Lambda
resource "aws_cloudwatch_log_group" "comprehend_medical_logs" {
  name              = "/aws/lambda/${var.environment}-comprehend-medical"
  retention_in_days = 90
  kms_key_id        = aws_kms_key.healthcare_data.arn

  tags = {
    Name        = "${var.environment}-comprehend-medical-logs"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

# DynamoDB Table for Medical Entities
resource "aws_dynamodb_table" "medical_entities" {
  name           = "${var.environment}-medical-entities"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "patientId"
  range_key      = "timestamp"

  attribute {
    name = "patientId"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.healthcare_data.arn
  }

  tags = {
    Name        = "${var.environment}-medical-entities"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

# CloudWatch Alarms for Comprehend Medical
resource "aws_cloudwatch_metric_alarm" "comprehend_medical_errors" {
  alarm_name          = "${var.environment}-comprehend-medical-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "Alert when Comprehend Medical Lambda has errors"
  alarm_actions       = [aws_sns_topic.error_notification.arn]

  dimensions = {
    FunctionName = aws_lambda_function.comprehend_medical.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "comprehend_medical_duration" {
  alarm_name          = "${var.environment}-comprehend-medical-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = "60000" # 60 seconds
  alarm_description   = "Alert when Comprehend Medical processing takes too long"
  alarm_actions       = [aws_sns_topic.error_notification.arn]

  dimensions = {
    FunctionName = aws_lambda_function.comprehend_medical.function_name
  }
}

# Outputs
output "comprehend_medical_lambda_arn" {
  description = "ARN of the Comprehend Medical Lambda function"
  value       = aws_lambda_function.comprehend_medical.arn
}

output "medical_entities_table_name" {
  description = "Name of the medical entities DynamoDB table"
  value       = aws_dynamodb_table.medical_entities.name
}
