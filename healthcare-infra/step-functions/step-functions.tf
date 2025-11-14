# AWS Step Functions for Healthcare Patient Workflow Orchestration
# Patient Intake → Lab Processing → Billing

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# IAM Role for Step Functions
resource "aws_iam_role" "step_functions_role" {
  name = "${var.environment}-healthcare-step-functions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.environment}-healthcare-step-functions-role"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

# IAM Policy for Step Functions
resource "aws_iam_role_policy" "step_functions_policy" {
  name = "${var.environment}-healthcare-step-functions-policy"
  role = aws_iam_role.step_functions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          aws_lambda_function.patient_intake.arn,
          aws_lambda_function.data_validation.arn,
          aws_lambda_function.comprehend_medical.arn,
          aws_lambda_function.lab_order.arn,
          aws_lambda_function.lab_results_processor.arn,
          aws_lambda_function.billing_calculator.arn,
          aws_lambda_function.insurance_verification.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
        Resource = [
          aws_dynamodb_table.patients.arn,
          aws_dynamodb_table.lab_results.arn,
          aws_dynamodb_table.billing.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = [
          aws_sns_topic.lab_notification.arn,
          aws_sns_topic.billing_notification.arn,
          aws_sns_topic.error_notification.arn
        ]
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
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.healthcare_data.arn
      }
    ]
  })
}

# CloudWatch Log Group for Step Functions
resource "aws_cloudwatch_log_group" "step_functions_logs" {
  name              = "/aws/stepfunctions/${var.environment}-patient-workflow"
  retention_in_days = 90
  kms_key_id        = aws_kms_key.healthcare_data.arn

  tags = {
    Name        = "${var.environment}-step-functions-logs"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

# Patient Workflow State Machine
resource "aws_sfn_state_machine" "patient_workflow" {
  name     = "${var.environment}-patient-workflow"
  role_arn = aws_iam_role.step_functions_role.arn

  definition = templatefile("${path.module}/patient-workflow.json", {
    PatientIntakeLambdaArn            = aws_lambda_function.patient_intake.arn
    DataValidationLambdaArn           = aws_lambda_function.data_validation.arn
    ComprehendMedicalLambdaArn        = aws_lambda_function.comprehend_medical.arn
    LabOrderLambdaArn                 = aws_lambda_function.lab_order.arn
    LabResultsProcessorLambdaArn      = aws_lambda_function.lab_results_processor.arn
    BillingCalculatorLambdaArn        = aws_lambda_function.billing_calculator.arn
    InsuranceVerificationLambdaArn    = aws_lambda_function.insurance_verification.arn
    LabNotificationTopicArn           = aws_sns_topic.lab_notification.arn
    BillingNotificationTopicArn       = aws_sns_topic.billing_notification.arn
    ErrorNotificationTopicArn         = aws_sns_topic.error_notification.arn
    LabResultsTableName               = aws_dynamodb_table.lab_results.name
    BillingTableName                  = aws_dynamodb_table.billing.name
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.step_functions_logs.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tracing_configuration {
    enabled = true
  }

  tags = {
    Name        = "${var.environment}-patient-workflow"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

# SNS Topics for Notifications
resource "aws_sns_topic" "lab_notification" {
  name              = "${var.environment}-lab-notification"
  kms_master_key_id = aws_kms_key.healthcare_data.id

  tags = {
    Name        = "${var.environment}-lab-notification"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

resource "aws_sns_topic" "billing_notification" {
  name              = "${var.environment}-billing-notification"
  kms_master_key_id = aws_kms_key.healthcare_data.id

  tags = {
    Name        = "${var.environment}-billing-notification"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

resource "aws_sns_topic" "error_notification" {
  name              = "${var.environment}-error-notification"
  kms_master_key_id = aws_kms_key.healthcare_data.id

  tags = {
    Name        = "${var.environment}-error-notification"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

# CloudWatch Alarms for Step Functions
resource "aws_cloudwatch_metric_alarm" "workflow_failed" {
  alarm_name          = "${var.environment}-patient-workflow-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ExecutionsFailed"
  namespace           = "AWS/States"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Alert when patient workflow executions fail"
  alarm_actions       = [aws_sns_topic.error_notification.arn]

  dimensions = {
    StateMachineArn = aws_sfn_state_machine.patient_workflow.arn
  }
}

resource "aws_cloudwatch_metric_alarm" "workflow_duration" {
  alarm_name          = "${var.environment}-patient-workflow-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ExecutionTime"
  namespace           = "AWS/States"
  period              = "300"
  statistic           = "Average"
  threshold           = "300000" # 5 minutes in milliseconds
  alarm_description   = "Alert when workflow execution takes longer than expected"
  alarm_actions       = [aws_sns_topic.error_notification.arn]

  dimensions = {
    StateMachineArn = aws_sfn_state_machine.patient_workflow.arn
  }
}

# Outputs
output "state_machine_arn" {
  description = "ARN of the patient workflow state machine"
  value       = aws_sfn_state_machine.patient_workflow.arn
}

output "state_machine_name" {
  description = "Name of the patient workflow state machine"
  value       = aws_sfn_state_machine.patient_workflow.name
}
