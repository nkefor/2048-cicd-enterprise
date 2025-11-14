# API Gateway for Healthcare Endpoints
# RESTful API with HIPAA-compliant security controls

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# REST API
resource "aws_api_gateway_rest_api" "healthcare_api" {
  name        = "${var.environment}-healthcare-api"
  description = "Healthcare API for patient intake, lab results, and billing"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name        = "${var.environment}-healthcare-api"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

# API Gateway Resources
# /patients
resource "aws_api_gateway_resource" "patients" {
  rest_api_id = aws_api_gateway_rest_api.healthcare_api.id
  parent_id   = aws_api_gateway_rest_api.healthcare_api.root_resource_id
  path_part   = "patients"
}

# /patients/{patientId}
resource "aws_api_gateway_resource" "patient_detail" {
  rest_api_id = aws_api_gateway_rest_api.healthcare_api.id
  parent_id   = aws_api_gateway_resource.patients.id
  path_part   = "{patientId}"
}

# /lab-results
resource "aws_api_gateway_resource" "lab_results" {
  rest_api_id = aws_api_gateway_rest_api.healthcare_api.id
  parent_id   = aws_api_gateway_rest_api.healthcare_api.root_resource_id
  path_part   = "lab-results"
}

# /billing
resource "aws_api_gateway_resource" "billing" {
  rest_api_id = aws_api_gateway_rest_api.healthcare_api.id
  parent_id   = aws_api_gateway_rest_api.healthcare_api.root_resource_id
  path_part   = "billing"
}

# /workflow
resource "aws_api_gateway_resource" "workflow" {
  rest_api_id = aws_api_gateway_rest_api.healthcare_api.id
  parent_id   = aws_api_gateway_rest_api.healthcare_api.root_resource_id
  path_part   = "workflow"
}

# Cognito Authorizer
resource "aws_api_gateway_authorizer" "cognito_authorizer" {
  name          = "${var.environment}-cognito-authorizer"
  rest_api_id   = aws_api_gateway_rest_api.healthcare_api.id
  type          = "COGNITO_USER_POOLS"
  provider_arns = [var.cognito_user_pool_arn]

  identity_source = "method.request.header.Authorization"
}

# POST /patients - Create Patient
resource "aws_api_gateway_method" "create_patient" {
  rest_api_id   = aws_api_gateway_rest_api.healthcare_api.id
  resource_id   = aws_api_gateway_resource.patients.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id

  request_validator_id = aws_api_gateway_request_validator.validator.id
}

resource "aws_api_gateway_integration" "create_patient_integration" {
  rest_api_id             = aws_api_gateway_rest_api.healthcare_api.id
  resource_id             = aws_api_gateway_resource.patients.id
  http_method             = aws_api_gateway_method.create_patient.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.patient_intake_lambda_invoke_arn
}

# GET /patients/{patientId} - Get Patient
resource "aws_api_gateway_method" "get_patient" {
  rest_api_id   = aws_api_gateway_rest_api.healthcare_api.id
  resource_id   = aws_api_gateway_resource.patient_detail.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id

  request_parameters = {
    "method.request.path.patientId" = true
  }
}

resource "aws_api_gateway_integration" "get_patient_integration" {
  rest_api_id             = aws_api_gateway_rest_api.healthcare_api.id
  resource_id             = aws_api_gateway_resource.patient_detail.id
  http_method             = aws_api_gateway_method.get_patient.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.patient_intake_lambda_invoke_arn
}

# POST /workflow - Start Patient Workflow
resource "aws_api_gateway_method" "start_workflow" {
  rest_api_id   = aws_api_gateway_rest_api.healthcare_api.id
  resource_id   = aws_api_gateway_resource.workflow.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
}

resource "aws_api_gateway_integration" "start_workflow_integration" {
  rest_api_id             = aws_api_gateway_rest_api.healthcare_api.id
  resource_id             = aws_api_gateway_resource.workflow.id
  http_method             = aws_api_gateway_method.start_workflow.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:${var.aws_region}:states:action/StartExecution"
  credentials             = aws_iam_role.api_gateway_step_functions_role.arn

  request_templates = {
    "application/json" = <<EOF
{
  "input": "$util.escapeJavaScript($input.json('$'))",
  "stateMachineArn": "${var.step_functions_arn}"
}
EOF
  }
}

resource "aws_api_gateway_method_response" "start_workflow_response" {
  rest_api_id = aws_api_gateway_rest_api.healthcare_api.id
  resource_id = aws_api_gateway_resource.workflow.id
  http_method = aws_api_gateway_method.start_workflow.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "start_workflow_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.healthcare_api.id
  resource_id = aws_api_gateway_resource.workflow.id
  http_method = aws_api_gateway_method.start_workflow.http_method
  status_code = aws_api_gateway_method_response.start_workflow_response.status_code

  depends_on = [aws_api_gateway_integration.start_workflow_integration]
}

# Request Validator
resource "aws_api_gateway_request_validator" "validator" {
  name                        = "${var.environment}-request-validator"
  rest_api_id                 = aws_api_gateway_rest_api.healthcare_api.id
  validate_request_body       = true
  validate_request_parameters = true
}

# IAM Role for API Gateway to invoke Step Functions
resource "aws_iam_role" "api_gateway_step_functions_role" {
  name = "${var.environment}-api-gateway-step-functions-role"

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
}

resource "aws_iam_role_policy" "api_gateway_step_functions_policy" {
  name = "${var.environment}-api-gateway-step-functions-policy"
  role = aws_iam_role.api_gateway_step_functions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = var.step_functions_arn
      }
    ]
  })
}

# Lambda Permissions for API Gateway
resource "aws_lambda_permission" "api_gateway_patient_intake" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.patient_intake_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.healthcare_api.execution_arn}/*/*"
}

# API Deployment
resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.healthcare_api.id

  depends_on = [
    aws_api_gateway_integration.create_patient_integration,
    aws_api_gateway_integration.get_patient_integration,
    aws_api_gateway_integration.start_workflow_integration
  ]

  lifecycle {
    create_before_destroy = true
  }
}

# API Stage
resource "aws_api_gateway_stage" "stage" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.healthcare_api.id
  stage_name    = var.environment

  xray_tracing_enabled = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
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
    Name        = "${var.environment}-api-stage"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/apigateway/${var.environment}-healthcare-api"
  retention_in_days = 90
  kms_key_id        = var.kms_key_arn

  tags = {
    Name        = "${var.environment}-api-gateway-logs"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

# WAF Web ACL for API Gateway
resource "aws_wafv2_web_acl" "api_gateway_waf" {
  name  = "${var.environment}-api-gateway-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "RateLimitRule"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name               = "RateLimitRule"
      sampled_requests_enabled  = true
    }
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name               = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled  = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name               = "${var.environment}-api-gateway-waf"
    sampled_requests_enabled  = true
  }

  tags = {
    Name        = "${var.environment}-api-gateway-waf"
    Environment = var.environment
    Compliance  = "HIPAA"
  }
}

# Associate WAF with API Gateway
resource "aws_wafv2_web_acl_association" "api_gateway_waf_association" {
  resource_arn = aws_api_gateway_stage.stage.arn
  web_acl_arn  = aws_wafv2_web_acl.api_gateway_waf.arn
}

# Variables
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN"
  type        = string
}

variable "patient_intake_lambda_invoke_arn" {
  description = "Patient Intake Lambda invoke ARN"
  type        = string
}

variable "patient_intake_lambda_function_name" {
  description = "Patient Intake Lambda function name"
  type        = string
}

variable "step_functions_arn" {
  description = "Step Functions state machine ARN"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN"
  type        = string
}

# Outputs
output "api_gateway_url" {
  description = "API Gateway invoke URL"
  value       = aws_api_gateway_stage.stage.invoke_url
}

output "api_gateway_id" {
  description = "API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.healthcare_api.id
}
