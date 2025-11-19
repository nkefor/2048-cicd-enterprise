# Lambda function for visitor counter
resource "aws_lambda_function" "visitor_counter" {
  filename         = "${path.module}/../lambda-deployment.zip"
  function_name    = "${var.project_name}-visitor-counter"
  role             = aws_iam_role.lambda.arn
  handler          = "visitor_counter.lambda_handler"
  source_code_hash = filebase64sha256("${path.module}/../lambda-deployment.zip")
  runtime          = "python3.11"
  timeout          = 10
  memory_size      = 256

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.visitor_counter.name
      ENVIRONMENT    = var.environment
    }
  }

  tracing_config {
    mode = "Active"
  }

  tags = {
    Name = "${var.project_name}-visitor-counter"
  }
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.visitor_counter.function_name}"
  retention_in_days = 14

  tags = {
    Name = "${var.project_name}-lambda-logs"
  }
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.visitor_counter.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.visitor_api.execution_arn}/*/*"
}

# CloudWatch Alarms for Lambda
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project_name}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Alert when Lambda function has more than 5 errors in 5 minutes"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.visitor_counter.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${var.project_name}-lambda-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Alert when Lambda function is throttled"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.visitor_counter.function_name
  }
}
