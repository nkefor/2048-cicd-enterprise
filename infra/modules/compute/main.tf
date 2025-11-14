# Compute Module - API Gateway, Lambda, Step Functions

# API Gateway REST API
resource "aws_api_gateway_rest_api" "healthcare" {
  name        = var.api_gateway_name
  description = "Healthcare API Gateway with HIPAA compliance"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name       = var.api_gateway_name
    Compliance = "HIPAA"
  }
}

# API Gateway Authorizer (Cognito)
resource "aws_api_gateway_authorizer" "cognito" {
  name          = "${var.environment}-cognito-authorizer"
  type          = "COGNITO_USER_POOLS"
  rest_api_id   = aws_api_gateway_rest_api.healthcare.id
  provider_arns = [var.cognito_user_pool_arn]
}

# API Gateway Request Validator
resource "aws_api_gateway_request_validator" "healthcare" {
  name                        = "${var.environment}-request-validator"
  rest_api_id                 = aws_api_gateway_rest_api.healthcare.id
  validate_request_body       = true
  validate_request_parameters = true
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "healthcare" {
  rest_api_id = aws_api_gateway_rest_api.healthcare.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_rest_api.healthcare.body,
      aws_api_gateway_resource.patients.id,
      aws_api_gateway_method.patients_post.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_method.patients_post,
    aws_api_gateway_integration.patients_post
  ]
}

# API Gateway Stage
resource "aws_api_gateway_stage" "healthcare" {
  deployment_id = aws_api_gateway_deployment.healthcare.id
  rest_api_id   = aws_api_gateway_rest_api.healthcare.id
  stage_name    = var.environment

  xray_tracing_enabled = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  tags = {
    Name       = "${var.environment}-api-stage"
    Compliance = "HIPAA"
  }
}

# API Gateway CloudWatch Log Group
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.environment}/healthcare"
  retention_in_days = 365
  kms_key_id        = var.kms_key_arn

  tags = {
    Name       = "${var.environment}-api-gateway-logs"
    Compliance = "HIPAA"
  }
}

# API Gateway Resources
resource "aws_api_gateway_resource" "patients" {
  rest_api_id = aws_api_gateway_rest_api.healthcare.id
  parent_id   = aws_api_gateway_rest_api.healthcare.root_resource_id
  path_part   = "patients"
}

# API Gateway Methods
resource "aws_api_gateway_method" "patients_post" {
  rest_api_id   = aws_api_gateway_rest_api.healthcare.id
  resource_id   = aws_api_gateway_resource.patients.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id

  request_validator_id = aws_api_gateway_request_validator.healthcare.id

  request_models = {
    "application/json" = aws_api_gateway_model.patient_intake.name
  }
}

# API Gateway Model for Patient Intake
resource "aws_api_gateway_model" "patient_intake" {
  rest_api_id  = aws_api_gateway_rest_api.healthcare.id
  name         = "PatientIntakeModel"
  description  = "Schema for patient intake request"
  content_type = "application/json"

  schema = jsonencode({
    "$schema" = "http://json-schema.org/draft-04/schema#"
    title     = "PatientIntake"
    type      = "object"
    required  = ["patientId", "personalInfo", "insurance"]
    properties = {
      patientId = {
        type = "string"
      }
      personalInfo = {
        type = "object"
        properties = {
          firstName = { type = "string" }
          lastName  = { type = "string" }
          dob       = { type = "string" }
          ssn       = { type = "string" }
        }
        required = ["firstName", "lastName", "dob"]
      }
      insurance = {
        type = "object"
        properties = {
          provider   = { type = "string" }
          policyId   = { type = "string" }
          groupId    = { type = "string" }
        }
      }
      requestedTests = {
        type = "array"
        items = { type = "string" }
      }
    }
  })
}

# API Gateway Integration with Step Functions
resource "aws_api_gateway_integration" "patients_post" {
  rest_api_id = aws_api_gateway_rest_api.healthcare.id
  resource_id = aws_api_gateway_resource.patients.id
  http_method = aws_api_gateway_method.patients_post.http_method

  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:states:action/StartExecution"
  credentials             = aws_iam_role.api_gateway_step_functions.arn

  request_templates = {
    "application/json" = jsonencode({
      stateMachineArn = aws_sfn_state_machine.patient_workflow.arn
      input           = "$util.escapeJavaScript($input.body)"
    })
  }
}

# API Gateway Method Response
resource "aws_api_gateway_method_response" "patients_post_200" {
  rest_api_id = aws_api_gateway_rest_api.healthcare.id
  resource_id = aws_api_gateway_resource.patients.id
  http_method = aws_api_gateway_method.patients_post.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

# API Gateway Integration Response
resource "aws_api_gateway_integration_response" "patients_post" {
  rest_api_id = aws_api_gateway_rest_api.healthcare.id
  resource_id = aws_api_gateway_resource.patients.id
  http_method = aws_api_gateway_method.patients_post.http_method
  status_code = aws_api_gateway_method_response.patients_post_200.status_code

  depends_on = [aws_api_gateway_integration.patients_post]
}

# IAM Role for API Gateway to invoke Step Functions
resource "aws_iam_role" "api_gateway_step_functions" {
  name = "${var.environment}-api-gateway-sfn-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.environment}-api-gateway-sfn-role"
  }
}

resource "aws_iam_role_policy" "api_gateway_step_functions" {
  name = "${var.environment}-api-gateway-sfn-policy"
  role = aws_iam_role.api_gateway_step_functions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = [
          aws_sfn_state_machine.patient_workflow.arn
        ]
      }
    ]
  })
}

# Step Functions State Machine - Patient Workflow
resource "aws_sfn_state_machine" "patient_workflow" {
  name     = "${var.environment}-patient-workflow"
  role_arn = aws_iam_role.step_functions.arn

  definition = templatefile("${path.module}/workflows/patient_workflow.json", {
    patient_intake_function_arn           = aws_lambda_function.patient_intake.arn
    insurance_eligibility_function_arn    = aws_lambda_function.insurance_eligibility.arn
    lab_scheduler_function_arn            = aws_lambda_function.lab_scheduler.arn
    comprehend_medical_function_arn       = aws_lambda_function.comprehend_medical_extraction.arn
    billing_generator_function_arn        = aws_lambda_function.billing_generator.arn
    provider_notification_function_arn    = aws_lambda_function.provider_notification.arn
    claim_submission_function_arn         = aws_lambda_function.claim_submission.arn
    manual_review_topic_arn              = aws_sns_topic.manual_review.arn
    intake_failure_topic_arn             = aws_sns_topic.intake_failure.arn
    patients_table_name                  = "Patients"
    lab_results_table_name               = "LabResults"
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.step_functions.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tracing_configuration {
    enabled = true
  }

  tags = {
    Name       = "${var.environment}-patient-workflow"
    Compliance = "HIPAA"
  }
}

# CloudWatch Log Group for Step Functions
resource "aws_cloudwatch_log_group" "step_functions" {
  name              = "/aws/vendedlogs/states/${var.environment}-patient-workflow"
  retention_in_days = 365
  kms_key_id        = var.kms_key_arn

  tags = {
    Name       = "${var.environment}-step-functions-logs"
    Compliance = "HIPAA"
  }
}

# IAM Role for Step Functions
resource "aws_iam_role" "step_functions" {
  name = "${var.environment}-step-functions-role"

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
    Name = "${var.environment}-step-functions-role"
  }
}

resource "aws_iam_role_policy" "step_functions" {
  name = "${var.environment}-step-functions-policy"
  role = aws_iam_role.step_functions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          "${aws_lambda_function.patient_intake.arn}",
          "${aws_lambda_function.insurance_eligibility.arn}",
          "${aws_lambda_function.lab_scheduler.arn}",
          "${aws_lambda_function.comprehend_medical_extraction.arn}",
          "${aws_lambda_function.billing_generator.arn}",
          "${aws_lambda_function.provider_notification.arn}",
          "${aws_lambda_function.claim_submission.arn}"
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
          "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/Patients",
          "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/LabResults"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = [
          aws_sns_topic.manual_review.arn,
          aws_sns_topic.intake_failure.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lambda Functions
resource "aws_lambda_function" "patient_intake" {
  filename      = "${path.module}/lambda/patient_intake.zip"
  function_name = "${var.environment}-patient-intake"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 30
  memory_size   = 512

  environment {
    variables = {
      ENVIRONMENT         = var.environment
      PATIENTS_TABLE_NAME = "Patients"
    }
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = var.security_group_ids
  }

  kms_key_arn = var.kms_key_arn

  tracing_config {
    mode = "Active"
  }

  tags = {
    Name       = "${var.environment}-patient-intake"
    Compliance = "HIPAA"
  }
}

resource "aws_lambda_function" "insurance_eligibility" {
  filename      = "${path.module}/lambda/insurance_eligibility.zip"
  function_name = "${var.environment}-insurance-eligibility"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 30
  memory_size   = 512

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = var.security_group_ids
  }

  kms_key_arn = var.kms_key_arn

  tracing_config {
    mode = "Active"
  }

  tags = {
    Name       = "${var.environment}-insurance-eligibility"
    Compliance = "HIPAA"
  }
}

resource "aws_lambda_function" "lab_scheduler" {
  filename      = "${path.module}/lambda/lab_scheduler.zip"
  function_name = "${var.environment}-lab-scheduler"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 30
  memory_size   = 512

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = var.security_group_ids
  }

  kms_key_arn = var.kms_key_arn

  tracing_config {
    mode = "Active"
  }

  tags = {
    Name       = "${var.environment}-lab-scheduler"
    Compliance = "HIPAA"
  }
}

resource "aws_lambda_function" "comprehend_medical_extraction" {
  filename      = "${path.module}/lambda/comprehend_medical.zip"
  function_name = "${var.environment}-comprehend-medical-extraction"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 60
  memory_size   = 1024

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = var.security_group_ids
  }

  kms_key_arn = var.kms_key_arn

  tracing_config {
    mode = "Active"
  }

  tags = {
    Name       = "${var.environment}-comprehend-medical"
    Compliance = "HIPAA"
  }
}

resource "aws_lambda_function" "billing_generator" {
  filename      = "${path.module}/lambda/billing_generator.zip"
  function_name = "${var.environment}-billing-generator"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 30
  memory_size   = 512

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = var.security_group_ids
  }

  kms_key_arn = var.kms_key_arn

  tracing_config {
    mode = "Active"
  }

  tags = {
    Name       = "${var.environment}-billing-generator"
    Compliance = "HIPAA"
  }
}

resource "aws_lambda_function" "provider_notification" {
  filename      = "${path.module}/lambda/provider_notification.zip"
  function_name = "${var.environment}-provider-notification"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 30
  memory_size   = 256

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = var.security_group_ids
  }

  kms_key_arn = var.kms_key_arn

  tracing_config {
    mode = "Active"
  }

  tags = {
    Name       = "${var.environment}-provider-notification"
    Compliance = "HIPAA"
  }
}

resource "aws_lambda_function" "claim_submission" {
  filename      = "${path.module}/lambda/claim_submission.zip"
  function_name = "${var.environment}-claim-submission"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 30
  memory_size   = 512

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = var.security_group_ids
  }

  kms_key_arn = var.kms_key_arn

  tracing_config {
    mode = "Active"
  }

  tags = {
    Name       = "${var.environment}-claim-submission"
    Compliance = "HIPAA"
  }
}

# IAM Role for Lambda Functions
resource "aws_iam_role" "lambda_execution" {
  name = "${var.environment}-lambda-execution-role"

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
    Name = "${var.environment}-lambda-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_execution" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_permissions" {
  name = "${var.environment}-lambda-permissions"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          "arn:aws:dynamodb:*:*:table/Patients",
          "arn:aws:dynamodb:*:*:table/LabResults",
          "arn:aws:dynamodb:*:*:table/Insurance",
          "arn:aws:dynamodb:*:*:table/Claims"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "comprehendmedical:DetectEntitiesV2",
          "comprehendmedical:DetectPHI",
          "comprehendmedical:InferICD10CM",
          "comprehendmedical:InferRxNorm"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = [var.kms_key_arn]
      },
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      }
    ]
  })
}

# SNS Topics
resource "aws_sns_topic" "manual_review" {
  name              = "${var.environment}-manual-review-required"
  kms_master_key_id = var.kms_key_arn

  tags = {
    Name = "${var.environment}-manual-review"
  }
}

resource "aws_sns_topic" "intake_failure" {
  name              = "${var.environment}-intake-failure"
  kms_master_key_id = var.kms_key_arn

  tags = {
    Name = "${var.environment}-intake-failure"
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
