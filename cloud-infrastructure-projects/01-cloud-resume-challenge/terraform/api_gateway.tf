# API Gateway HTTP API
resource "aws_apigatewayv2_api" "visitor_api" {
  name          = "${var.project_name}-visitor-api"
  protocol_type = "HTTP"
  description   = "API for visitor counter"

  cors_configuration {
    allow_origins = ["https://${var.domain_name}"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["Content-Type", "X-Amz-Date", "Authorization", "X-Api-Key", "X-Amz-Security-Token"]
    max_age       = 300
  }

  tags = {
    Name = "${var.project_name}-visitor-api"
  }
}

# API Gateway Stage
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.visitor_api.id
  name        = "$default"
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
      errorMessage   = "$context.error.message"
    })
  }

  default_route_settings {
    throttling_burst_limit = 100
    throttling_rate_limit  = 50
  }

  tags = {
    Name = "${var.project_name}-api-stage"
  }
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}-visitor-api"
  retention_in_days = 14

  tags = {
    Name = "${var.project_name}-api-gateway-logs"
  }
}

# API Gateway Integration with Lambda
resource "aws_apigatewayv2_integration" "visitor_counter" {
  api_id           = aws_apigatewayv2_api.visitor_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.visitor_counter.invoke_arn

  integration_method     = "POST"
  payload_format_version = "2.0"
  timeout_milliseconds   = 10000
}

# API Gateway Route for POST /visitors
resource "aws_apigatewayv2_route" "post_visitors" {
  api_id    = aws_apigatewayv2_api.visitor_api.id
  route_key = "POST /visitors"
  target    = "integrations/${aws_apigatewayv2_integration.visitor_counter.id}"
}

# API Gateway Route for GET /visitors (optional, for checking count)
resource "aws_apigatewayv2_route" "get_visitors" {
  api_id    = aws_apigatewayv2_api.visitor_api.id
  route_key = "GET /visitors"
  target    = "integrations/${aws_apigatewayv2_integration.visitor_counter.id}"
}

# Custom domain for API Gateway (optional)
resource "aws_apigatewayv2_domain_name" "api" {
  domain_name = "api.${var.domain_name}"

  domain_name_configuration {
    certificate_arn = aws_acm_certificate.website.arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }

  depends_on = [aws_acm_certificate_validation.website]

  tags = {
    Name = "${var.project_name}-api-domain"
  }
}

# API Gateway domain mapping
resource "aws_apigatewayv2_api_mapping" "api" {
  api_id      = aws_apigatewayv2_api.visitor_api.id
  domain_name = aws_apigatewayv2_domain_name.api.id
  stage       = aws_apigatewayv2_stage.default.id
}
