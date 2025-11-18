# Custom EventBridge event bus for task events
resource "aws_cloudwatch_event_bus" "task_events" {
  name = "${var.project_name}-events-${var.environment}"

  tags = {
    Name = "${var.project_name}-event-bus"
  }
}

# EventBridge rule for task created events
resource "aws_cloudwatch_event_rule" "task_created" {
  name           = "${var.project_name}-task-created-${var.environment}"
  description    = "Trigger when a new task is created"
  event_bus_name = aws_cloudwatch_event_bus.task_events.name

  event_pattern = jsonencode({
    source      = ["task-manager"]
    detail-type = ["TaskCreated"]
  })

  tags = {
    Name = "${var.project_name}-task-created-rule"
  }
}

# Target for task created events
resource "aws_cloudwatch_event_target" "task_created" {
  rule           = aws_cloudwatch_event_rule.task_created.name
  event_bus_name = aws_cloudwatch_event_bus.task_events.name
  arn            = aws_lambda_function.task_created_handler.arn
}

# Lambda permission for EventBridge to invoke task_created_handler
resource "aws_lambda_permission" "task_created_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.task_created_handler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.task_created.arn
}

# EventBridge rule for task updated events
resource "aws_cloudwatch_event_rule" "task_updated" {
  name           = "${var.project_name}-task-updated-${var.environment}"
  description    = "Trigger when a task is updated"
  event_bus_name = aws_cloudwatch_event_bus.task_events.name

  event_pattern = jsonencode({
    source      = ["task-manager"]
    detail-type = ["TaskUpdated"]
  })

  tags = {
    Name = "${var.project_name}-task-updated-rule"
  }
}

# Target for task updated events
resource "aws_cloudwatch_event_target" "task_updated" {
  rule           = aws_cloudwatch_event_rule.task_updated.name
  event_bus_name = aws_cloudwatch_event_bus.task_events.name
  arn            = aws_lambda_function.task_updated_handler.arn
}

# Lambda permission for EventBridge to invoke task_updated_handler
resource "aws_lambda_permission" "task_updated_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.task_updated_handler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.task_updated.arn
}

# EventBridge rule for task completed events
resource "aws_cloudwatch_event_rule" "task_completed" {
  name           = "${var.project_name}-task-completed-${var.environment}"
  description    = "Trigger when a task is completed"
  event_bus_name = aws_cloudwatch_event_bus.task_events.name

  event_pattern = jsonencode({
    source      = ["task-manager"]
    detail-type = ["TaskCompleted"]
  })

  tags = {
    Name = "${var.project_name}-task-completed-rule"
  }
}

# Target for task completed events
resource "aws_cloudwatch_event_target" "task_completed" {
  rule           = aws_cloudwatch_event_rule.task_completed.name
  event_bus_name = aws_cloudwatch_event_bus.task_events.name
  arn            = aws_lambda_function.task_completed_handler.arn
}

# Lambda permission for EventBridge to invoke task_completed_handler
resource "aws_lambda_permission" "task_completed_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.task_completed_handler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.task_completed.arn
}

# EventBridge rule for high-priority tasks (example of conditional routing)
resource "aws_cloudwatch_event_rule" "high_priority_task" {
  name           = "${var.project_name}-high-priority-task-${var.environment}"
  description    = "Trigger Step Functions workflow for high-priority tasks"
  event_bus_name = aws_cloudwatch_event_bus.task_events.name

  event_pattern = jsonencode({
    source      = ["task-manager"]
    detail-type = ["TaskCreated"]
    detail = {
      priority = ["high"]
    }
  })

  tags = {
    Name = "${var.project_name}-high-priority-task-rule"
  }
}

# Target for high-priority tasks to Step Functions
resource "aws_cloudwatch_event_target" "high_priority_task" {
  rule           = aws_cloudwatch_event_rule.high_priority_task.name
  event_bus_name = aws_cloudwatch_event_bus.task_events.name
  arn            = aws_sfn_state_machine.task_approval.arn
  role_arn       = aws_iam_role.eventbridge_stepfunctions.arn
}

# IAM role for EventBridge to invoke Step Functions
resource "aws_iam_role" "eventbridge_stepfunctions" {
  name = "${var.project_name}-eventbridge-stepfunctions-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-eventbridge-stepfunctions-role"
  }
}

# IAM policy for EventBridge to start Step Functions execution
resource "aws_iam_role_policy" "eventbridge_stepfunctions" {
  name = "stepfunctions-execution"
  role = aws_iam_role.eventbridge_stepfunctions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = aws_sfn_state_machine.task_approval.arn
      }
    ]
  })
}

# CloudWatch Log Group for EventBridge
resource "aws_cloudwatch_log_group" "eventbridge" {
  name              = "/aws/events/${var.project_name}-${var.environment}"
  retention_in_days = var.cloudwatch_retention_days
  kms_key_id        = aws_kms_key.task_encryption.arn
}
