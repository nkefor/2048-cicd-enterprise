# API Gateway HTTP API for task management
resource "aws_apigatewayv2_api" "task_api" {
  name          = "${var.project_name}-api-${var.environment}"
  protocol_type = "HTTP"
  description   = "Serverless Task Management API"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization", "X-Amz-Date", "X-Api-Key", "X-Amz-Security-Token"]
    max_age       = 300
  }

  tags = {
    Name = "${var.project_name}-api"
  }
}

# API Gateway stage
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.task_api.id
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
      integrationError = "$context.integrationErrorMessage"
    })
  }

  default_route_settings {
    throttling_burst_limit = var.api_throttle_burst_limit
    throttling_rate_limit  = var.api_throttle_rate_limit
  }

  tags = {
    Name = "${var.project_name}-api-stage"
  }
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}-${var.environment}"
  retention_in_days = var.cloudwatch_retention_days
  kms_key_id        = aws_kms_key.task_encryption.arn
}

# Lambda integrations

# Create Task Integration
resource "aws_apigatewayv2_integration" "create_task" {
  api_id             = aws_apigatewayv2_api.task_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.create_task.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "create_task" {
  api_id    = aws_apigatewayv2_api.task_api.id
  route_key = "POST /tasks"
  target    = "integrations/${aws_apigatewayv2_integration.create_task.id}"
}

resource "aws_lambda_permission" "create_task" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_task.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.task_api.execution_arn}/*/*/tasks"
}

# Get Task Integration
resource "aws_apigatewayv2_integration" "get_task" {
  api_id             = aws_apigatewayv2_api.task_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.get_task.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_task" {
  api_id    = aws_apigatewayv2_api.task_api.id
  route_key = "GET /tasks/{taskId}"
  target    = "integrations/${aws_apigatewayv2_integration.get_task.id}"
}

resource "aws_lambda_permission" "get_task" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_task.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.task_api.execution_arn}/*/*/tasks/*"
}

# Update Task Integration
resource "aws_apigatewayv2_integration" "update_task" {
  api_id             = aws_apigatewayv2_api.task_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.update_task.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "update_task" {
  api_id    = aws_apigatewayv2_api.task_api.id
  route_key = "PUT /tasks/{taskId}"
  target    = "integrations/${aws_apigatewayv2_integration.update_task.id}"
}

resource "aws_lambda_permission" "update_task" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update_task.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.task_api.execution_arn}/*/*/tasks/*"
}

# Delete Task Integration
resource "aws_apigatewayv2_integration" "delete_task" {
  api_id             = aws_apigatewayv2_api.task_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.delete_task.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "delete_task" {
  api_id    = aws_apigatewayv2_api.task_api.id
  route_key = "DELETE /tasks/{taskId}"
  target    = "integrations/${aws_apigatewayv2_integration.delete_task.id}"
}

resource "aws_lambda_permission" "delete_task" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.delete_task.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.task_api.execution_arn}/*/*/tasks/*"
}

# List Tasks Integration
resource "aws_apigatewayv2_integration" "list_tasks" {
  api_id             = aws_apigatewayv2_api.task_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.list_tasks.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "list_tasks" {
  api_id    = aws_apigatewayv2_api.task_api.id
  route_key = "GET /tasks"
  target    = "integrations/${aws_apigatewayv2_integration.list_tasks.id}"
}

resource "aws_lambda_permission" "list_tasks" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list_tasks.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.task_api.execution_arn}/*/*/tasks"
}
