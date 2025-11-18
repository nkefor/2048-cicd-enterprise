# Lambda function for creating tasks
resource "aws_lambda_function" "create_task" {
  filename      = "${path.module}/../lambda/api/create-task/deployment.zip"
  function_name = "${var.project_name}-create-task-${var.environment}"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  source_code_hash = fileexists("${path.module}/../lambda/api/create-task/deployment.zip") ? filebase64sha256("${path.module}/../lambda/api/create-task/deployment.zip") : null

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.tasks.name
      EVENT_BUS_NAME      = aws_cloudwatch_event_bus.task_events.name
      KMS_KEY_ID          = aws_kms_key.task_encryption.id
      ENVIRONMENT         = var.environment
    }
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  tags = {
    Name = "${var.project_name}-create-task"
  }

  depends_on = [
    aws_iam_role_policy.lambda_cloudwatch,
    aws_iam_role_policy.lambda_dynamodb,
    aws_iam_role_policy.lambda_eventbridge
  ]
}

# CloudWatch Log Group for create_task
resource "aws_cloudwatch_log_group" "create_task" {
  name              = "/aws/lambda/${aws_lambda_function.create_task.function_name}"
  retention_in_days = var.cloudwatch_retention_days
  kms_key_id        = aws_kms_key.task_encryption.arn
}

# Lambda function for getting task
resource "aws_lambda_function" "get_task" {
  filename      = "${path.module}/../lambda/api/get-task/deployment.zip"
  function_name = "${var.project_name}-get-task-${var.environment}"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  source_code_hash = fileexists("${path.module}/../lambda/api/get-task/deployment.zip") ? filebase64sha256("${path.module}/../lambda/api/get-task/deployment.zip") : null

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.tasks.name
      KMS_KEY_ID          = aws_kms_key.task_encryption.id
      ENVIRONMENT         = var.environment
    }
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  tags = {
    Name = "${var.project_name}-get-task"
  }
}

resource "aws_cloudwatch_log_group" "get_task" {
  name              = "/aws/lambda/${aws_lambda_function.get_task.function_name}"
  retention_in_days = var.cloudwatch_retention_days
  kms_key_id        = aws_kms_key.task_encryption.arn
}

# Lambda function for updating tasks
resource "aws_lambda_function" "update_task" {
  filename      = "${path.module}/../lambda/api/update-task/deployment.zip"
  function_name = "${var.project_name}-update-task-${var.environment}"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  source_code_hash = fileexists("${path.module}/../lambda/api/update-task/deployment.zip") ? filebase64sha256("${path.module}/../lambda/api/update-task/deployment.zip") : null

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.tasks.name
      EVENT_BUS_NAME      = aws_cloudwatch_event_bus.task_events.name
      KMS_KEY_ID          = aws_kms_key.task_encryption.id
      ENVIRONMENT         = var.environment
    }
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  tags = {
    Name = "${var.project_name}-update-task"
  }
}

resource "aws_cloudwatch_log_group" "update_task" {
  name              = "/aws/lambda/${aws_lambda_function.update_task.function_name}"
  retention_in_days = var.cloudwatch_retention_days
  kms_key_id        = aws_kms_key.task_encryption.arn
}

# Lambda function for deleting tasks
resource "aws_lambda_function" "delete_task" {
  filename      = "${path.module}/../lambda/api/delete-task/deployment.zip"
  function_name = "${var.project_name}-delete-task-${var.environment}"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  source_code_hash = fileexists("${path.module}/../lambda/api/delete-task/deployment.zip") ? filebase64sha256("${path.module}/../lambda/api/delete-task/deployment.zip") : null

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.tasks.name
      EVENT_BUS_NAME      = aws_cloudwatch_event_bus.task_events.name
      KMS_KEY_ID          = aws_kms_key.task_encryption.id
      ENVIRONMENT         = var.environment
    }
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  tags = {
    Name = "${var.project_name}-delete-task"
  }
}

resource "aws_cloudwatch_log_group" "delete_task" {
  name              = "/aws/lambda/${aws_lambda_function.delete_task.function_name}"
  retention_in_days = var.cloudwatch_retention_days
  kms_key_id        = aws_kms_key.task_encryption.arn
}

# Lambda function for listing tasks
resource "aws_lambda_function" "list_tasks" {
  filename      = "${path.module}/../lambda/api/list-tasks/deployment.zip"
  function_name = "${var.project_name}-list-tasks-${var.environment}"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  source_code_hash = fileexists("${path.module}/../lambda/api/list-tasks/deployment.zip") ? filebase64sha256("${path.module}/../lambda/api/list-tasks/deployment.zip") : null

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.tasks.name
      KMS_KEY_ID          = aws_kms_key.task_encryption.id
      ENVIRONMENT         = var.environment
    }
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  tags = {
    Name = "${var.project_name}-list-tasks"
  }
}

resource "aws_cloudwatch_log_group" "list_tasks" {
  name              = "/aws/lambda/${aws_lambda_function.list_tasks.function_name}"
  retention_in_days = var.cloudwatch_retention_days
  kms_key_id        = aws_kms_key.task_encryption.arn
}

# Event-driven Lambda functions

# Task created event handler
resource "aws_lambda_function" "task_created_handler" {
  filename      = "${path.module}/../lambda/events/task-created/deployment.zip"
  function_name = "${var.project_name}-task-created-handler-${var.environment}"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  source_code_hash = fileexists("${path.module}/../lambda/events/task-created/deployment.zip") ? filebase64sha256("${path.module}/../lambda/events/task-created/deployment.zip") : null

  environment {
    variables = {
      DYNAMODB_TABLE_NAME  = aws_dynamodb_table.tasks.name
      STATE_MACHINE_ARN    = aws_sfn_state_machine.task_approval.arn
      KMS_KEY_ID           = aws_kms_key.task_encryption.id
      ENVIRONMENT          = var.environment
    }
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  tags = {
    Name = "${var.project_name}-task-created-handler"
  }
}

resource "aws_cloudwatch_log_group" "task_created_handler" {
  name              = "/aws/lambda/${aws_lambda_function.task_created_handler.function_name}"
  retention_in_days = var.cloudwatch_retention_days
  kms_key_id        = aws_kms_key.task_encryption.arn
}

# Task updated event handler
resource "aws_lambda_function" "task_updated_handler" {
  filename      = "${path.module}/../lambda/events/task-updated/deployment.zip"
  function_name = "${var.project_name}-task-updated-handler-${var.environment}"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  source_code_hash = fileexists("${path.module}/../lambda/events/task-updated/deployment.zip") ? filebase64sha256("${path.module}/../lambda/events/task-updated/deployment.zip") : null

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.tasks.name
      KMS_KEY_ID          = aws_kms_key.task_encryption.id
      ENVIRONMENT         = var.environment
    }
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  tags = {
    Name = "${var.project_name}-task-updated-handler"
  }
}

resource "aws_cloudwatch_log_group" "task_updated_handler" {
  name              = "/aws/lambda/${aws_lambda_function.task_updated_handler.function_name}"
  retention_in_days = var.cloudwatch_retention_days
  kms_key_id        = aws_kms_key.task_encryption.arn
}

# Task completed event handler
resource "aws_lambda_function" "task_completed_handler" {
  filename      = "${path.module}/../lambda/events/task-completed/deployment.zip"
  function_name = "${var.project_name}-task-completed-handler-${var.environment}"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  source_code_hash = fileexists("${path.module}/../lambda/events/task-completed/deployment.zip") ? filebase64sha256("${path.module}/../lambda/events/task-completed/deployment.zip") : null

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.tasks.name
      KMS_KEY_ID          = aws_kms_key.task_encryption.id
      ENVIRONMENT         = var.environment
    }
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  tags = {
    Name = "${var.project_name}-task-completed-handler"
  }
}

resource "aws_cloudwatch_log_group" "task_completed_handler" {
  name              = "/aws/lambda/${aws_lambda_function.task_completed_handler.function_name}"
  retention_in_days = var.cloudwatch_retention_days
  kms_key_id        = aws_kms_key.task_encryption.arn
}
