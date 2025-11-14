# Healthcare Lambda Functions
# Core workflow functions for patient intake, lab processing, and billing

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Common Lambda Role
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.environment}-healthcare-lambda-role"

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
    Name        = "${var.environment}-healthcare-lambda-role"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

# Lambda Policy
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.environment}-healthcare-lambda-policy"
  role = aws_iam_role.lambda_execution_role.id

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
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.patients.arn,
          aws_dynamodb_table.lab_results.arn,
          aws_dynamodb_table.billing.arn,
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
        Resource = var.kms_key_arn
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = "*"
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

# Patient Intake Lambda
resource "aws_lambda_function" "patient_intake" {
  filename         = "${path.module}/functions/patient-intake.zip"
  function_name    = "${var.environment}-patient-intake"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "index.handler"
  runtime         = "python3.11"
  timeout         = 60
  memory_size     = 512

  environment {
    variables = {
      PATIENTS_TABLE = aws_dynamodb_table.patients.name
      KMS_KEY_ID     = var.kms_key_id
      ENVIRONMENT    = var.environment
    }
  }

  tracing_config {
    mode = "Active"
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  tags = {
    Name        = "${var.environment}-patient-intake"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

# Data Validation Lambda
resource "aws_lambda_function" "data_validation" {
  filename         = "${path.module}/functions/data-validation.zip"
  function_name    = "${var.environment}-data-validation"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "index.handler"
  runtime         = "python3.11"
  timeout         = 30
  memory_size     = 256

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  tracing_config {
    mode = "Active"
  }

  tags = {
    Name        = "${var.environment}-data-validation"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

# Lab Order Lambda
resource "aws_lambda_function" "lab_order" {
  filename         = "${path.module}/functions/lab-order.zip"
  function_name    = "${var.environment}-lab-order"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "index.handler"
  runtime         = "python3.11"
  timeout         = 60
  memory_size     = 512

  environment {
    variables = {
      LAB_RESULTS_TABLE = aws_dynamodb_table.lab_results.name
      KMS_KEY_ID        = var.kms_key_id
      ENVIRONMENT       = var.environment
    }
  }

  tracing_config {
    mode = "Active"
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  tags = {
    Name        = "${var.environment}-lab-order"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

# Lab Results Processor Lambda
resource "aws_lambda_function" "lab_results_processor" {
  filename         = "${path.module}/functions/lab-results-processor.zip"
  function_name    = "${var.environment}-lab-results-processor"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "index.handler"
  runtime         = "python3.11"
  timeout         = 60
  memory_size     = 512

  environment {
    variables = {
      LAB_RESULTS_TABLE = aws_dynamodb_table.lab_results.name
      PATIENTS_TABLE    = aws_dynamodb_table.patients.name
      KMS_KEY_ID        = var.kms_key_id
      ENVIRONMENT       = var.environment
    }
  }

  tracing_config {
    mode = "Active"
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  tags = {
    Name        = "${var.environment}-lab-results-processor"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

# Billing Calculator Lambda
resource "aws_lambda_function" "billing_calculator" {
  filename         = "${path.module}/functions/billing-calculator.zip"
  function_name    = "${var.environment}-billing-calculator"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "index.handler"
  runtime         = "python3.11"
  timeout         = 60
  memory_size     = 512

  environment {
    variables = {
      BILLING_TABLE = aws_dynamodb_table.billing.name
      KMS_KEY_ID    = var.kms_key_id
      ENVIRONMENT   = var.environment
    }
  }

  tracing_config {
    mode = "Active"
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  tags = {
    Name        = "${var.environment}-billing-calculator"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

# Insurance Verification Lambda
resource "aws_lambda_function" "insurance_verification" {
  filename         = "${path.module}/functions/insurance-verification.zip"
  function_name    = "${var.environment}-insurance-verification"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "index.handler"
  runtime         = "python3.11"
  timeout         = 60
  memory_size     = 256

  environment {
    variables = {
      PATIENTS_TABLE = aws_dynamodb_table.patients.name
      KMS_KEY_ID     = var.kms_key_id
      ENVIRONMENT    = var.environment
    }
  }

  tracing_config {
    mode = "Active"
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  tags = {
    Name        = "${var.environment}-insurance-verification"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "lambda_logs" {
  for_each = toset([
    aws_lambda_function.patient_intake.function_name,
    aws_lambda_function.data_validation.function_name,
    aws_lambda_function.lab_order.function_name,
    aws_lambda_function.lab_results_processor.function_name,
    aws_lambda_function.billing_calculator.function_name,
    aws_lambda_function.insurance_verification.function_name
  ])

  name              = "/aws/lambda/${each.key}"
  retention_in_days = 90
  kms_key_id        = var.kms_key_arn

  tags = {
    Name        = "${var.environment}-${each.key}-logs"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

# Variables
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "kms_key_id" {
  description = "KMS key ID"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "lambda_security_group_id" {
  description = "Lambda security group ID"
  type        = string
}

# Outputs
output "patient_intake_lambda_arn" {
  value = aws_lambda_function.patient_intake.arn
}

output "data_validation_lambda_arn" {
  value = aws_lambda_function.data_validation.arn
}

output "lab_order_lambda_arn" {
  value = aws_lambda_function.lab_order.arn
}

output "lab_results_processor_lambda_arn" {
  value = aws_lambda_function.lab_results_processor.arn
}

output "billing_calculator_lambda_arn" {
  value = aws_lambda_function.billing_calculator.arn
}

output "insurance_verification_lambda_arn" {
  value = aws_lambda_function.insurance_verification.arn
}
