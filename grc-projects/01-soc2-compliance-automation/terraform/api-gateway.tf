# API Gateway HTTP API for Compliance Queries
resource "aws_apigatewayv2_api" "compliance_api" {
  name          = "${local.prefix}-api"
  protocol_type = "HTTP"
  description   = "SOC 2 Compliance Query API"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST"]
    allow_headers = ["content-type", "x-amz-date", "authorization"]
    max_age       = 300
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.prefix}-api"
    }
  )
}

# API Gateway Stage
resource "aws_apigatewayv2_stage" "compliance_api" {
  api_id      = aws_apigatewayv2_api.compliance_api.id
  name        = var.environment
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${local.prefix}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.compliance.arn

  tags = local.common_tags
}

# Lambda Integration for Compliance Status
resource "aws_lambda_function" "api_compliance_status" {
  filename      = "${path.module}/../lambda/api-compliance-status.zip"
  function_name = "${local.prefix}-api-status"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "index.handler"
  runtime       = var.lambda_runtime
  timeout       = 30
  memory_size   = 256

  environment {
    variables = {
      EVIDENCE_TABLE       = aws_dynamodb_table.compliance_evidence.name
      CONTROL_STATUS_TABLE = aws_dynamodb_table.control_status.name
      FINDINGS_TABLE       = aws_dynamodb_table.audit_findings.name
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.prefix}-api-status"
    }
  )
}

resource "aws_lambda_permission" "api_gateway_status" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_compliance_status.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.compliance_api.execution_arn}/*/*"
}

# API Route: GET /compliance/status
resource "aws_apigatewayv2_integration" "compliance_status" {
  api_id           = aws_apigatewayv2_api.compliance_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.api_compliance_status.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "compliance_status" {
  api_id    = aws_apigatewayv2_api.compliance_api.id
  route_key = "GET /compliance/status"
  target    = "integrations/${aws_apigatewayv2_integration.compliance_status.id}"
}

# API Route: GET /compliance/controls
resource "aws_apigatewayv2_route" "compliance_controls" {
  api_id    = aws_apigatewayv2_api.compliance_api.id
  route_key = "GET /compliance/controls"
  target    = "integrations/${aws_apigatewayv2_integration.compliance_status.id}"
}

# API Route: GET /compliance/findings
resource "aws_apigatewayv2_route" "compliance_findings" {
  api_id    = aws_apigatewayv2_api.compliance_api.id
  route_key = "GET /compliance/findings"
  target    = "integrations/${aws_apigatewayv2_integration.compliance_status.id}"
}

# API Route: POST /compliance/scan
resource "aws_apigatewayv2_route" "trigger_scan" {
  api_id    = aws_apigatewayv2_api.compliance_api.id
  route_key = "POST /compliance/scan"
  target    = "integrations/${aws_apigatewayv2_integration.compliance_status.id}"
}

# QuickSight Dashboard (Optional)
variable "enable_quicksight" {
  description = "Enable QuickSight dashboard for compliance visualization"
  type        = bool
  default     = false
}

resource "aws_quicksight_data_source" "compliance" {
  count          = var.enable_quicksight ? 1 : 0
  data_source_id = "${local.prefix}-datasource"
  name           = "${local.prefix} Compliance Data"
  type           = "ATHENA"

  parameters {
    athena {
      work_group = "primary"
    }
  }

  tags = local.common_tags
}

resource "aws_quicksight_dashboard" "compliance" {
  count          = var.enable_quicksight ? 1 : 0
  dashboard_id   = "${local.prefix}-dashboard"
  name           = "SOC 2 Compliance Dashboard"
  version_description = "SOC 2 compliance monitoring and reporting"

  tags = local.common_tags
}
